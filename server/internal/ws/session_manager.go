package ws

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/google/uuid"
	"voxel-server/internal/data"
)

type SessionManager struct {
	sessions map[string]*data.GameSession
	mu       sync.RWMutex
	hub      *Hub
}

func NewSessionManager(hub *Hub) *SessionManager {
	return &SessionManager{
		sessions: make(map[string]*data.GameSession),
		hub:      hub,
	}
}

func (sm *SessionManager) CreateSession(hostID, gameType string) *data.GameSession {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	id := uuid.New().String()
	session := &data.GameSession{
		ID:        id,
		HostID:    hostID,
		GameType:  gameType,
		State:     data.GameStateLobby,
		Players:   []string{hostID},
		CreatedAt: time.Now(),
	}
	sm.sessions[id] = session
	
	// Broadcast update
	sm.broadcastSessionUpdate(session)
	return session
}

func (sm *SessionManager) JoinSession(sessionID, userID string) *data.GameSession {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, ok := sm.sessions[sessionID]
	if !ok {
		return nil
	}

	// Check if already in
	for _, pid := range session.Players {
		if pid == userID {
			return session
		}
	}

	session.Players = append(session.Players, userID)
	sm.broadcastSessionUpdate(session)
	return session
}

func (sm *SessionManager) StartGame(sessionID, userID string) *data.GameSession {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	session, ok := sm.sessions[sessionID]
	if !ok || session.HostID != userID {
		return nil
	}

	session.State = data.GameStatePlaying
	sm.broadcastSessionUpdate(session)
	return session
}

func (sm *SessionManager) broadcastSessionUpdate(session *data.GameSession) {
	msg, _ := json.Marshal(map[string]interface{}{
		"type":    "session_update",
		"payload": session,
	})
	
	// Broadcast to all players in the session
	// In a real app, we'd filter by players. For now, broadcast to everyone or handle in Hub?
	// Let's broadcast to everyone so they see the lobby list update or use Hub's broadcast.
	sm.hub.Broadcast <- BroadcastMessage{Message: msg, Exclude: nil}
}

func (sm *SessionManager) HandleMessage(msgType string, payload map[string]interface{}, client *Client) {
	// Parse payload based on msgType
	switch msgType {
	case "create_session":
		gameType, _ := payload["gameType"].(string)
		log.Printf("Creating session %s for host %s", gameType, client.UserID)
		session := sm.CreateSession(client.UserID, gameType)
		if session != nil {
			client.SessionID = session.ID
		}

	case "join_session":
		sessionID, _ := payload["sessionId"].(string)
		log.Printf("User %s joining session %s", client.UserID, sessionID)
		session := sm.JoinSession(sessionID, client.UserID)
		if session != nil {
			client.SessionID = session.ID
		}

	case "start_game":
		sessionID, _ := payload["sessionId"].(string)
		log.Printf("Host %s starting session %s", client.UserID, sessionID)
		sm.StartGame(sessionID, client.UserID)
	}
}
