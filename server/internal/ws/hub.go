package ws

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"voxel-server/internal/data"

	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"
)

// BroadcastMessage packages a message with an optional client to exclude from the broadcast.
type BroadcastMessage struct {
	Message []byte
	Exclude *Client
}

// Hub maintains the set of active clients and broadcasts messages to the
// clients.
type Hub struct {
	// Registered clients.
	Clients map[*Client]bool

	// Inbound messages from the clients.
	Broadcast chan BroadcastMessage

	// Register requests from the clients.
	Register chan *Client

	// Unregister requests from clients.
	Unregister chan *Client

	// SessionManager handles game sessions.
	SessionManager *SessionManager

	// UserPositions stores the last known position of each user.
	UserPositions map[string]interface{}
}

// NewHub creates a new Hub.
func NewHub() *Hub {
	h := &Hub{
		Broadcast:     make(chan BroadcastMessage),
		Register:      make(chan *Client),
		Unregister:    make(chan *Client),
		Clients:       make(map[*Client]bool),
		UserPositions: make(map[string]interface{}),
	}
	h.SessionManager = NewSessionManager(h)
	return h
}

// Run starts the hub's event loop.
func (h *Hub) Run() {
	for {
		select {
		case client := <-h.Register:
			h.Clients[client] = true
			log.Printf("Client registered: %s", client.UserID)
			h.sendExistingEvents(client)
			h.sendExistingPositions(client)
		case client := <-h.Unregister:
			if _, ok := h.Clients[client]; ok {
				userID := client.UserID
				delete(h.Clients, client)
				delete(h.UserPositions, userID)
				close(client.Send)
				log.Printf("Client unregistered: %s", userID)

				// Broadcast leave message to ALL clients (global or session)
				msg, _ := json.Marshal(Message{
					Type:    "leave",
					Payload: map[string]string{"userId": userID},
				})

				if client.SessionID != "" {
					// Broadcast to session
					h.broadcastToSession(msg, client.SessionID, nil)
				} else {
					// Broadcast to global world
					h.broadcastMessage(msg, nil)
				}
			}
		case bm := <-h.Broadcast:
			var msg Message
			if err := json.Unmarshal(bm.Message, &msg); err != nil {
				log.Printf("error unmarshalling broadcast message: %v", err)
				continue
			}

			// WebRTC signaling messages need direct peer-to-peer routing
			if msg.Type == "webrtc_offer" || msg.Type == "webrtc_answer" || msg.Type == "webrtc_ice_candidate" {
				// Extract targetId from payload
				if payload, ok := msg.Payload.(map[string]interface{}); ok {
					if targetId, ok := payload["targetId"].(string); ok && targetId != "" {
						log.Printf("🎯 Routing %s from %s to %s", msg.Type, bm.Exclude.UserID, targetId)

						// Create message with senderId for the receiver
						routedMsg := Message{
							Type: msg.Type,
							Payload: map[string]interface{}{
								"senderId": bm.Exclude.UserID,
								"data":     payload["data"],
							},
						}
						routedBytes, _ := json.Marshal(routedMsg)
						h.sendToUser(targetId, routedBytes)
					} else {
						log.Printf("⚠️ WebRTC message missing targetId: %v", payload)
					}
				}
			} else if msg.Type == "move" || msg.Type == "audio" {
				// Update server state for "move" events (Global or Session)
				if msg.Type == "move" {
					if payload, ok := msg.Payload.(map[string]interface{}); ok {
						if userID, ok := payload["userId"].(string); ok && userID != "" {
							h.UserPositions[userID] = payload
						}
					}
				}

				if bm.Exclude != nil {
					// Broadcast to the session (matching SessionID, including empty string)
					h.broadcastToSession(bm.Message, bm.Exclude.SessionID, bm.Exclude)
				}
			} else {
				// Messages not tied to a session are broadcast globally
				h.broadcastMessage(bm.Message, bm.Exclude)
			}
		}
	}
}

// broadcastToSession sends a message to all clients in a specific session, optionally excluding one.
func (h *Hub) broadcastToSession(message []byte, sessionID string, exclude *Client) {
	for client := range h.Clients {
		if client.SessionID == sessionID && client != exclude {
			select {
			case client.Send <- message:
			default:
				log.Printf("Forcing disconnect of slow client in session %s: %s", sessionID, client.UserID)
				close(client.Send)
				delete(h.Clients, client)
			}
		}
	}
}

// broadcastMessage sends a message to all clients, optionally excluding one.
func (h *Hub) broadcastMessage(message []byte, exclude *Client) {
	for client := range h.Clients {
		if client == exclude {
			continue
		}
		select {
		case client.Send <- message:
		default:
			log.Printf("Forcing disconnect of slow client: %s", client.UserID)
			close(client.Send)
			delete(h.Clients, client)
		}
	}
}

func (h *Hub) HandleCreateEvent(payload map[string]interface{}, client *Client) {
	// Parse payload into VoxelEvent
	event := data.VoxelEvent{
		Title:       payload["title"].(string),
		Description: payload["description"].(string),
		X:           payload["x"].(float64),
		Y:           payload["y"].(float64),
		Latitude:    payload["latitude"].(float64),
		Longitude:   payload["longitude"].(float64),
		CreatorID:   payload["creatorId"].(string),
		StartTime:   time.Now(), // Simplified
		TicketPrice: payload["ticketPrice"].(float64),
		HasTickets:  payload["hasTickets"].(bool),
		VoxelTheme:  payload["voxelTheme"].(string),
		IsPrivate:   payload["isPrivate"].(bool),
		AttendeeIDs: []string{payload["creatorId"].(string)},
		CreatedAt:   time.Now(),
	}

	// Save to DB
	collection := data.GetCollection("events")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	_, err := collection.InsertOne(ctx, event)
	if err != nil {
		log.Printf("Failed to save event: %v", err)
		return
	}

	// Broadcast to all
	msg, _ := json.Marshal(Message{
		Type:    "event_created",
		Payload: event,
	})
	h.broadcastMessage(msg, nil)
}

func (h *Hub) HandleJoinEvent(payload map[string]interface{}, client *Client) {
	eventID := payload["eventId"].(string)
	userID := client.UserID

	collection := data.GetCollection("events")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get event details
	var event data.VoxelEvent
	err := collection.FindOne(ctx, bson.M{"id": eventID}).Decode(&event)
	if err != nil {
		log.Printf("Failed to find event: %v", err)
		return
	}

	// Get user info
	usersCollection := data.GetCollection("users")
	objID, _ := primitive.ObjectIDFromHex(userID)
	var user data.User
	err = usersCollection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)

	_, err = collection.UpdateOne(
		ctx,
		bson.M{"id": eventID},
		bson.M{"$addToSet": bson.M{"attendeeIds": userID}},
	)
	if err != nil {
		log.Printf("Failed to join event: %v", err)
		return
	}

	// Send notification to event creator
	if event.CreatorID != userID {
		notificationMsg, _ := json.Marshal(Message{
			Type: "event_participant_joined",
			Payload: map[string]interface{}{
				"eventId":    eventID,
				"eventTitle": event.Title,
				"userId":     userID,
				"username":   user.Username,
			},
		})
		h.sendToUser(event.CreatorID, notificationMsg)
		log.Printf("📬 Sent join notification to event creator %s", event.CreatorID)
	}

	// Broadcast update (we send the whole event for simplicity or just the update)
	h.broadcastEventUpdate(eventID)
}

func (h *Hub) HandleLeaveEvent(payload map[string]interface{}, client *Client) {
	eventID := payload["eventId"].(string)
	userID := client.UserID

	collection := data.GetCollection("events")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get event details
	var event data.VoxelEvent
	err := collection.FindOne(ctx, bson.M{"id": eventID}).Decode(&event)
	if err != nil {
		log.Printf("Failed to find event: %v", err)
		return
	}

	// Get user info
	usersCollection := data.GetCollection("users")
	objID, _ := primitive.ObjectIDFromHex(userID)
	var user data.User
	err = usersCollection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)

	_, err = collection.UpdateOne(
		ctx,
		bson.M{"id": eventID},
		bson.M{"$pull": bson.M{"attendeeIds": userID}},
	)
	if err != nil {
		log.Printf("Failed to leave event: %v", err)
		return
	}

	// Send notification to event creator
	if event.CreatorID != userID {
		notificationMsg, _ := json.Marshal(Message{
			Type: "event_participant_left",
			Payload: map[string]interface{}{
				"eventId":    eventID,
				"eventTitle": event.Title,
				"userId":     userID,
				"username":   user.Username,
			},
		})
		h.sendToUser(event.CreatorID, notificationMsg)
		log.Printf("📬 Sent leave notification to event creator %s", event.CreatorID)
	}

	h.broadcastEventUpdate(eventID)
}

func (h *Hub) broadcastEventUpdate(eventID string) {
	collection := data.GetCollection("events")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	var event data.VoxelEvent
	err := collection.FindOne(ctx, bson.M{"id": eventID}).Decode(&event)
	if err != nil {
		return
	}

	msg, _ := json.Marshal(Message{
		Type:    "event_updated",
		Payload: event,
	})
	h.broadcastMessage(msg, nil)
}

func (h *Hub) sendExistingEvents(client *Client) {
	collection := data.GetCollection("events")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cursor, err := collection.Find(ctx, bson.M{})
	if err != nil {
		log.Printf("Failed to fetch events: %v", err)
		return
	}
	defer cursor.Close(ctx)

	var events []data.VoxelEvent
	if err = cursor.All(ctx, &events); err != nil {
		log.Printf("Failed to decode events: %v", err)
		return
	}

	if len(events) == 0 {
		return
	}

	msg, _ := json.Marshal(Message{
		Type:    "events_list",
		Payload: events,
	})
	client.Send <- msg
}

func (h *Hub) HandleKickUser(payload map[string]interface{}, client *Client) {
	roomID := payload["roomId"].(string)
	targetUserID := payload["targetUserId"].(string)
	creatorID := client.UserID

	collection := data.GetCollection("rooms")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	objID, _ := primitive.ObjectIDFromHex(roomID)
	var room data.Room
	err := collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
	if err != nil {
		log.Printf("Failed to find room: %v", err)
		return
	}

	if room.CreatorID != creatorID {
		log.Printf("Unauthorized kick attempt by %s in room %s", creatorID, roomID)
		return
	}

	// Remove from members list in DB
	_, err = collection.UpdateOne(
		ctx,
		bson.M{"_id": objID},
		bson.M{"$pull": bson.M{"members": bson.M{"userId": targetUserID}}},
	)
	if err != nil {
		log.Printf("Failed to remove member from DB: %v", err)
	}

	// Find the client and force them out
	for c := range h.Clients {
		if c.UserID == targetUserID && c.SessionID == roomID {
			msg, _ := json.Marshal(Message{
				Type:    "kicked",
				Payload: map[string]string{"roomId": roomID, "reason": "Kicked by creator"},
			})
			c.Send <- msg
			c.SessionID = "" // Move to global world
			log.Printf("User %s kicked from room %s", targetUserID, roomID)
		}
	}
}

func (h *Hub) HandleBanUser(payload map[string]interface{}, client *Client) {
	roomID := payload["roomId"].(string)
	targetUserID := payload["targetUserId"].(string)
	creatorID := client.UserID

	collection := data.GetCollection("rooms")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	objID, _ := primitive.ObjectIDFromHex(roomID)
	var room data.Room
	err := collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
	if err != nil {
		return
	}

	if room.CreatorID != creatorID {
		return
	}

	// Add to banned list and remove from members
	_, err = collection.UpdateOne(
		ctx,
		bson.M{"_id": objID},
		bson.M{
			"$addToSet": bson.M{"bannedUserIds": targetUserID},
			"$pull":     bson.M{"members": bson.M{"userId": targetUserID}},
		},
	)

	// Force out if currently in
	for c := range h.Clients {
		if c.UserID == targetUserID && c.SessionID == roomID {
			msg, _ := json.Marshal(Message{
				Type:    "banned",
				Payload: map[string]string{"roomId": roomID, "reason": "Banned by creator"},
			})
			c.Send <- msg
			c.SessionID = ""
		}
	}
}

// HandleJoinRoom switches a client's session to a room ID
func (h *Hub) HandleJoinRoom(payload map[string]interface{}, client *Client) {
	roomID, ok := payload["roomId"].(string)
	if !ok || roomID == "" {
		log.Printf("Invalid roomId in join_room payload")
		return
	}

	userID := client.UserID
	log.Printf("👥 User %s joining room %s", userID, roomID)

	// Update client's session ID to the room ID
	client.SessionID = roomID

	// Update room membership in database
	collection := data.GetCollection("rooms")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	// Get room details to find creator
	roomObjID, _ := primitive.ObjectIDFromHex(roomID)
	var room data.Room
	err := collection.FindOne(ctx, bson.M{"_id": roomObjID}).Decode(&room)
	if err != nil {
		log.Printf("❌ Failed to find room %s: %v", roomID, err)
		return
	}

	// Get user info
	usersCollection := data.GetCollection("users")
	objID, _ := primitive.ObjectIDFromHex(userID)
	var user data.User
	err = usersCollection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)
	if err != nil {
		log.Printf("❌ Failed to find user %s: %v", userID, err)
		return
	}

	// Add user to room members if not already present
	newMember := data.RoomMember{
		UserID:      userID,
		Username:    user.Username,
		AvatarUrl:   user.AvatarUrl,
		Role:        "member",
		JoinedAt:    time.Now(),
		Permissions: []string{"speak"},
	}

	_, err = collection.UpdateOne(
		ctx,
		bson.M{"_id": roomObjID},
		bson.M{"$addToSet": bson.M{"members": newMember}},
	)
	if err != nil {
		log.Printf("❌ Failed to add member to room: %v", err)
	}

	// Broadcast room join event to all room members
	msg, _ := json.Marshal(Message{
		Type: "room_joined",
		Payload: map[string]interface{}{
			"roomId":   roomID,
			"userId":   userID,
			"username": user.Username,
		},
	})
	h.broadcastToSession(msg, roomID, nil)

	// Send notification to room creator if they're not the one joining
	if room.CreatorID != userID {
		notificationMsg, _ := json.Marshal(Message{
			Type: "room_joined",
			Payload: map[string]interface{}{
				"roomId":   roomID,
				"roomName": room.Name,
				"userId":   userID,
				"username": user.Username,
			},
		})
		h.sendToUser(room.CreatorID, notificationMsg)
		log.Printf("📬 Sent join notification to room creator %s", room.CreatorID)
	}

	// Send existing positions of room members to the joining user
	h.sendExistingPositions(client)

	log.Printf("✅ User %s joined room %s", userID, roomID)
}

// HandleLobbyMessage broadcasts a chat message to all clients in the same session (room).
// Server is relay-only — no persistence. Clients store messages locally.
func (h *Hub) HandleLobbyMessage(payload map[string]interface{}, client *Client) {
	content, ok := payload["content"].(string)
	if !ok || content == "" {
		return
	}

	sessionID := client.SessionID
	if sessionID == "" {
		// Not in a room, ignore lobby message
		log.Printf("⚠️ User %s tried to send lobby message without being in a room", client.UserID)
		return
	}

	// Build the outbound message
	msgPayload := map[string]interface{}{
		"senderId":   client.UserID,
		"senderName": payload["senderName"],
		"content":    content,
		"roomId":     sessionID,
		"messageId":  payload["messageId"],
		"timestamp":  payload["timestamp"],
	}

	outMsg, _ := json.Marshal(Message{
		Type:    "lobby_message",
		Payload: msgPayload,
	})

	// Broadcast to all clients in this session (including sender for confirmation)
	h.broadcastToSession(outMsg, sessionID, nil)
	log.Printf("💬 Lobby message in room %s from %s: %s", sessionID, client.UserID, content)
}

// HandleTypingIndicator relays typing status to target user (private) or session (lobby).
func (h *Hub) HandleTypingIndicator(payload map[string]interface{}, client *Client) {
	isTyping, _ := payload["isTyping"].(bool)
	targetId, _ := payload["targetId"].(string)
	roomId, _ := payload["roomId"].(string)

	indicatorPayload := map[string]interface{}{
		"senderId": client.UserID,
		"isTyping": isTyping,
		"targetId": targetId,
		"roomId":   roomId,
	}

	outMsg, _ := json.Marshal(Message{
		Type:    "typing_indicator",
		Payload: indicatorPayload,
	})

	if roomId != "" {
		// Lobby typing — broadcast to session excluding sender
		h.broadcastToSession(outMsg, roomId, client)
	} else if targetId != "" {
		// Private typing — send to target user
		h.sendToUser(targetId, outMsg)
	}
}

// HandleMarkRead relays read receipt back to the original sender.
func (h *Hub) HandleMarkRead(payload map[string]interface{}, client *Client) {
	senderId, _ := payload["senderId"].(string)
	messageId, _ := payload["messageId"].(string)

	if senderId == "" || messageId == "" {
		return
	}

	receiptPayload := map[string]interface{}{
		"readerId":  client.UserID,
		"senderId":  senderId,
		"messageId": messageId,
	}

	outMsg, _ := json.Marshal(Message{
		Type:    "message_read_receipt",
		Payload: receiptPayload,
	})

	h.sendToUser(senderId, outMsg)
	log.Printf("✓✓ Read receipt: %s read message %s from %s", client.UserID, messageId, senderId)
}

func (h *Hub) sendExistingPositions(client *Client) {
	// Send positions of other clients in the same session
	for c := range h.Clients {
		if c.UserID == client.UserID {
			continue // Don't send own position
		}

		// check if in same session (room or global)
		if c.SessionID == client.SessionID {
			if pos, ok := h.UserPositions[c.UserID]; ok {
				msg, _ := json.Marshal(Message{
					Type:    "move",
					Payload: pos,
				})
				client.Send <- msg
			}
		}
	}
}

// HandleLeaveRoom returns a client to the global session
func (h *Hub) HandleLeaveRoom(payload map[string]interface{}, client *Client) {
	roomID := client.SessionID
	if roomID == "" {
		log.Printf("User %s is not in any room", client.UserID)
		return
	}

	userID := client.UserID
	log.Printf("👋 User %s leaving room %s", userID, roomID)

	// Get room details before leaving
	collection := data.GetCollection("rooms")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	roomObjID, _ := primitive.ObjectIDFromHex(roomID)
	var room data.Room
	err := collection.FindOne(ctx, bson.M{"_id": roomObjID}).Decode(&room)
	if err != nil {
		log.Printf("❌ Failed to find room %s: %v", roomID, err)
	}

	// Get user info for notification
	usersCollection := data.GetCollection("users")
	objID, _ := primitive.ObjectIDFromHex(userID)
	var user data.User
	err = usersCollection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)

	// Reset client's session ID to empty (global world)
	client.SessionID = ""

	// Remove user from room members in database
	_, err = collection.UpdateOne(
		ctx,
		bson.M{"_id": roomObjID},
		bson.M{"$pull": bson.M{"members": bson.M{"userId": userID}}},
	)
	if err != nil {
		log.Printf("❌ Failed to remove member from room: %v", err)
	}

	// Broadcast room leave event to remaining room members
	msg, _ := json.Marshal(Message{
		Type: "room_left",
		Payload: map[string]interface{}{
			"roomId": roomID,
			"userId": userID,
		},
	})
	h.broadcastToSession(msg, roomID, nil)

	// Send notification to room creator if they're not the one leaving
	if err == nil && room.CreatorID != userID {
		notificationMsg, _ := json.Marshal(Message{
			Type: "room_left",
			Payload: map[string]interface{}{
				"roomId":   roomID,
				"roomName": room.Name,
				"userId":   userID,
				"username": user.Username,
			},
		})
		h.sendToUser(room.CreatorID, notificationMsg)
		log.Printf("📬 Sent leave notification to room creator %s", room.CreatorID)
	}

	log.Printf("✅ User %s left room %s", userID, roomID)
}

// HandleSendMessage sends a private message to a specific user
func (h *Hub) HandleSendMessage(payload map[string]interface{}, client *Client) {
	receiverID, ok := payload["receiverId"].(string)
	if !ok || receiverID == "" {
		return
	}
	content, ok := payload["content"].(string)
	if !ok || content == "" {
		return
	}

	senderID := client.UserID

	// Save to DB
	msg := data.Message{
		SenderID:   senderID,
		ReceiverID: receiverID,
		Content:    content,
		Timestamp:  time.Now(),
		Read:       false,
	}

	collection := data.GetCollection("messages")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	res, err := collection.InsertOne(ctx, msg)
	if err != nil {
		log.Printf("❌ Failed to save message: %v", err)
		return
	}
	msg.ID = res.InsertedID.(primitive.ObjectID)

	// Send to Receiver
	outMsg, _ := json.Marshal(Message{
		Type:    "message_received",
		Payload: msg,
	})
	h.sendToUser(receiverID, outMsg)

	// Send ack to Sender (so they know it was sent/saved with ID)
	ackMsg, _ := json.Marshal(Message{
		Type:    "message_sent",
		Payload: msg,
	})
	client.Send <- ackMsg
}

// HandleFriendRequest sends a friend request
func (h *Hub) HandleFriendRequest(payload map[string]interface{}, client *Client) {
	receiverID, ok := payload["receiverId"].(string)
	if !ok || receiverID == "" {
		return
	}

	senderID := client.UserID

	// Save to DB
	req := data.FriendRequest{
		SenderID:   senderID,
		ReceiverID: receiverID,
		Status:     "pending",
		Timestamp:  time.Now(),
	}

	collection := data.GetCollection("friend_requests")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	res, err := collection.InsertOne(ctx, req)
	if err != nil {
		log.Printf("❌ Failed to save friend request: %v", err)
		return
	}
	req.ID = res.InsertedID.(primitive.ObjectID)

	// Send to Receiver
	outMsg, _ := json.Marshal(Message{
		Type:    "friend_request",
		Payload: req,
	})
	h.sendToUser(receiverID, outMsg)
}

// sendToUser sends a message to a specific user by ID
func (h *Hub) sendToUser(userID string, message []byte) {
	for client := range h.Clients {
		if client.UserID == userID {
			select {
			case client.Send <- message:
			default:
				close(client.Send)
				delete(h.Clients, client)
			}
		}
	}
}
