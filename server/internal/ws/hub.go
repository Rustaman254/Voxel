
package ws

import (
	"context"
	"encoding/json"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/bson"
	"voxel-server/internal/data"
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
		CreatorID:   payload["creatorId"].(string),
		StartTime:   time.Now(), // Simplified
		TicketPrice: payload["ticketPrice"].(float64),
		HasTickets:  payload["hasTickets"].(bool),
		VoxelTheme:  payload["voxelTheme"].(string),
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
