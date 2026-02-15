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

			// Session-specific events
			if msg.Type == "move" || msg.Type == "audio" ||
				msg.Type == "webrtc_offer" || msg.Type == "webrtc_answer" || msg.Type == "webrtc_ice_candidate" {

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

	_, err := collection.UpdateOne(
		ctx,
		bson.M{"id": eventID},
		bson.M{"$addToSet": bson.M{"attendeeIds": userID}},
	)
	if err != nil {
		log.Printf("Failed to join event: %v", err)
		return
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

	_, err := collection.UpdateOne(
		ctx,
		bson.M{"id": eventID},
		bson.M{"$pull": bson.M{"attendeeIds": userID}},
	)
	if err != nil {
		log.Printf("Failed to leave event: %v", err)
		return
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

func (h *Hub) sendExistingPositions(client *Client) {
	// Send positions one by one to simulate 'move' messages for new client
	for _, pos := range h.UserPositions {
		msg, _ := json.Marshal(Message{
			Type:    "move",
			Payload: pos,
		})
		client.Send <- msg
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

	// Get user info
	usersCollection := data.GetCollection("users")
	objID, _ := primitive.ObjectIDFromHex(userID)
	var user data.User
	err := usersCollection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)
	if err != nil {
		log.Printf("❌ Failed to find user %s: %v", userID, err)
		return
	}

	// Add user to room members if not already present
	roomObjID, _ := primitive.ObjectIDFromHex(roomID)
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

	log.Printf("✅ User %s joined room %s", userID, roomID)
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

	// Reset client's session ID to empty (global world)
	client.SessionID = ""

	// Remove user from room members in database
	collection := data.GetCollection("rooms")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	roomObjID, _ := primitive.ObjectIDFromHex(roomID)
	_, err := collection.UpdateOne(
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

	log.Printf("✅ User %s left room %s", userID, roomID)
}
