package data

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type User struct {
	ID        primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Username  string             `bson:"username" json:"username"`
	AvatarUrl string             `bson:"avatarUrl" json:"avatarUrl"`
	CreatedAt time.Time          `bson:"createdAt" json:"createdAt"`
	LastSeen  time.Time          `bson:"lastSeen" json:"lastSeen"`
	
	// Position Data
	X   float64 `bson:"x" json:"x"`
	Y   float64 `bson:"y" json:"y"`
	
	// IRL Data
	Latitude  float64 `bson:"latitude" json:"latitude"`
	Longitude float64 `bson:"longitude" json:"longitude"`
}

type AuthRequest struct {
	Username  string `json:"username"`
	AvatarUrl string `json:"avatarUrl"`
}

type AuthResponse struct {
	Token  string `json:"token"` // Just the UserID for now (Simulated "Token")
	UserID string `json:"userId"`
}

// Game Session Models
const (
	GameStateLobby    = "LOBBY"
	GameStatePlaying  = "PLAYING"
	GameStateFinished = "FINISHED"

	GameTypeProximity = "PROXIMITY_TAG"
	GameTypeTreasure  = "TREASURE_HUNT"
)

type GameSession struct {
	ID        string    `json:"id"`
	HostID    string    `json:"hostId"`
	GameType  string    `json:"gameType"`
	State     string    `json:"state"`
	Players   []string  `json:"players"` // List of UserIDs
	CreatedAt time.Time `json:"createdAt"`
}

type VoxelEvent struct {
	ID          string    `bson:"_id,omitempty" json:"id"`
	Title       string    `bson:"title" json:"title"`
	Description string    `bson:"description" json:"description"`
	X           float64   `bson:"x" json:"x"`
	Y           float64   `bson:"y" json:"y"`
	CreatorID   string    `bson:"creatorId" json:"creatorId"`
	StartTime   time.Time `bson:"startTime" json:"startTime"`
	TicketPrice float64   `bson:"ticketPrice" json:"ticketPrice"`
	HasTickets  bool      `bson:"hasTickets" json:"hasTickets"`
	VoxelTheme  string    `bson:"voxelTheme" json:"voxelTheme"`
	CreatedAt   time.Time `bson:"createdAt" json:"createdAt"`
}
