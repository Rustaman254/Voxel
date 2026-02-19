package ws

import (
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/gorilla/websocket"
)

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 2 * 1024 * 1024 // 2MB for large audio chunks
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  2048,
	WriteBufferSize: 2048,
	CheckOrigin: func(r *http.Request) bool {
		// In production, you'd want a more secure check
		return true
	},
}

type Client struct {
	Hub *Hub
	// The websocket connection.
	Conn *websocket.Conn
	// Buffered channel of outbound messages.
	Send chan []byte
	// User ID associated with this connection
	UserID string
	// SessionID associated with this connection
	SessionID string
}

type Message struct {
	Type    string      `json:"type"` // "update_position", "user_joined", "user_left"
	Payload interface{} `json:"payload"`
}

type PositionPayload struct {
	UserID string  `json:"userId"`
	X      float64 `json:"x"`
	Y      float64 `json:"y"`
	Lat    float64 `json:"latitude"`
	Lng    float64 `json:"longitude"`
}

// readPump pumps messages from the websocket connection to the hub.
func (c *Client) readPump() {
	defer func() {
		c.Hub.Unregister <- c
		c.Conn.Close()
		log.Printf("Client %s unregistered and connection closed.", c.UserID)
	}()
	c.Conn.SetReadLimit(maxMessageSize)
	c.Conn.SetReadDeadline(time.Now().Add(pongWait))
	c.Conn.SetPongHandler(func(string) error {
		c.Conn.SetReadDeadline(time.Now().Add(pongWait))
		log.Printf("Pong received from client %s", c.UserID)
		return nil
	})
	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("error: %v", err)
			}
			break
		}

		// Log received message
		log.Printf("Received message from %s: %s", c.UserID, string(message))

		// Unmarshal generic message
		var msg Message
		if err := json.Unmarshal(message, &msg); err != nil {
			log.Printf("error unmarshal: %v", err)
			continue
		}

		// Handle different types
		switch msg.Type {
		case "move", "audio", "webrtc_offer", "webrtc_answer", "webrtc_ice_candidate":
			c.Hub.Broadcast <- BroadcastMessage{Message: message, Exclude: c}
		case "create_event", "join_event", "leave_event":
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				if msg.Type == "create_event" {
					c.Hub.HandleCreateEvent(payload, c)
				} else if msg.Type == "join_event" {
					c.Hub.HandleJoinEvent(payload, c)
				} else if msg.Type == "leave_event" {
					c.Hub.HandleLeaveEvent(payload, c)
				}
			}
		case "kick_user", "ban_user":
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				if msg.Type == "kick_user" {
					c.Hub.HandleKickUser(payload, c)
				} else if msg.Type == "ban_user" {
					c.Hub.HandleBanUser(payload, c)
				}
			}
		case "join_room", "leave_room":
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				if msg.Type == "join_room" {
					c.Hub.HandleJoinRoom(payload, c)
				} else if msg.Type == "leave_room" {
					c.Hub.HandleLeaveRoom(payload, c)
				}
			}

		case "send_message", "friend_request":
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				if msg.Type == "send_message" {
					c.Hub.HandleSendMessage(payload, c)
				} else if msg.Type == "friend_request" {
					c.Hub.HandleFriendRequest(payload, c)
				} else if msg.Type == "friend_request_response" {
					c.Hub.HandleFriendRequestResponse(payload, c)
				}
			}
		case "lobby_message":
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				c.Hub.HandleLobbyMessage(payload, c)
			}
		case "typing_indicator":
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				c.Hub.HandleTypingIndicator(payload, c)
			}
		case "mark_read":
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				c.Hub.HandleMarkRead(payload, c)
			}
		case "create_session", "join_session", "start_game":
			if payload, ok := msg.Payload.(map[string]interface{}); ok {
				c.Hub.SessionManager.HandleMessage(msg.Type, payload, c)
			} else {
				log.Printf("Invalid payload for session message")
			}
		}
	}
}

// writePump pumps messages from the hub to the websocket connection.
func (c *Client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.Send:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				// The hub closed the channel.
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			w, err := c.Conn.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)

			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			c.Conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.Conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request, userId string, sessionId string) {
	log.Printf("📥 Incoming WS upgrade request for User: %s (Session: %s) from %s", userId, sessionId, r.RemoteAddr)
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("❌ WS Upgrade Error for User %s: %v", userId, err)
		return
	}
	log.Printf("✅ WS Upgrade Successful for User: %s", userId)
	client := &Client{
		Hub:       hub,
		Conn:      conn,
		Send:      make(chan []byte, 1024),
		UserID:    userId,
		SessionID: sessionId,
	}
	client.Hub.Register <- client

	// Allow collection of memory referenced by the caller by doing all work in
	// new goroutines.
	go client.writePump()
	go client.readPump()
}
