package data

import (
	"time"

	"go.mongodb.org/mongo-driver/bson/primitive"
)

type User struct {
	ID          primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Email       string             `bson:"email" json:"email"`
	Username    string             `bson:"username" json:"username"`
	DisplayName string             `bson:"displayName" json:"displayName"`
	Password    string             `bson:"password" json:"-"` // Never send to client
	AvatarUrl   string             `bson:"avatarUrl" json:"avatarUrl"`
	CreatedAt   time.Time          `bson:"createdAt" json:"createdAt"`
	LastSeen    time.Time          `bson:"lastSeen" json:"lastSeen"`

	// Position Data
	X float64 `bson:"x" json:"x"`
	Y float64 `bson:"y" json:"y"`

	// IRL Data
	Latitude  float64 `bson:"latitude" json:"latitude"`
	Longitude float64 `bson:"longitude" json:"longitude"`
}

type AuthRequest struct {
	Email       string `json:"email"`
	Password    string `json:"password"`
	Username    string `json:"username,omitempty"`
	DisplayName string `json:"displayName,omitempty"`
	AvatarUrl   string `json:"avatarUrl,omitempty"`
}

type AuthResponse struct {
	Token       string `json:"token"`
	UserID      string `json:"userId"`
	Username    string `json:"username"`
	DisplayName string `json:"displayName"`
	AvatarUrl   string `json:"avatarUrl"`
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
	Latitude    float64   `bson:"latitude" json:"latitude"`
	Longitude   float64   `bson:"longitude" json:"longitude"`
	CreatorID   string    `bson:"creatorId" json:"creatorId"`
	StartTime   time.Time `bson:"startTime" json:"startTime"`
	TicketPrice float64   `bson:"ticketPrice" json:"ticketPrice"`
	HasTickets  bool      `bson:"hasTickets" json:"hasTickets"`
	VoxelTheme  string    `bson:"voxelTheme" json:"voxelTheme"`
	IsPrivate   bool      `bson:"isPrivate" json:"isPrivate"`
	AttendeeIDs []string  `bson:"attendeeIds" json:"attendeeIds"`
	CreatedAt   time.Time `bson:"createdAt" json:"createdAt"`
}

// Room Models for Private Meetings
type RoomMember struct {
	UserID      string    `bson:"userId" json:"userId"`
	Username    string    `bson:"username" json:"username"`
	AvatarUrl   string    `bson:"avatarUrl" json:"avatarUrl"`
	Role        string    `bson:"role" json:"role"` // creator, admin, member
	JoinedAt    time.Time `bson:"joinedAt" json:"joinedAt"`
	Permissions []string  `bson:"permissions" json:"permissions"` // speak, invite, kick, edit
}

type Room struct {
	ID            primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Name          string             `bson:"name" json:"name"`
	Description   string             `bson:"description" json:"description"`
	CreatorID     string             `bson:"creatorId" json:"creatorId"`
	CreatedAt     time.Time          `bson:"createdAt" json:"createdAt"`
	IsPrivate     bool               `bson:"isPrivate" json:"isPrivate"`
	Members       []RoomMember       `bson:"members" json:"members"`
	X             float64            `bson:"x" json:"x"` // Virtual position in lobby
	Y             float64            `bson:"y" json:"y"`
	Latitude      float64            `bson:"latitude" json:"latitude"`
	Longitude     float64            `bson:"longitude" json:"longitude"`
	BannedUserIDs []string           `bson:"bannedUserIds" json:"bannedUserIds"`
}

// Enhanced Event Model with Attendance
type Attendee struct {
	UserID       string     `bson:"userId" json:"userId"`
	Username     string     `bson:"username" json:"username"`
	Email        string     `bson:"email" json:"email"`
	AvatarUrl    string     `bson:"avatarUrl" json:"avatarUrl"`
	Status       string     `bson:"status" json:"status"` // pending, approved, rejected
	RegisteredAt time.Time  `bson:"registeredAt" json:"registeredAt"`
	CheckedInAt  *time.Time `bson:"checkedInAt,omitempty" json:"checkedInAt,omitempty"`
}

type EventModel struct {
	ID               primitive.ObjectID `bson:"_id,omitempty" json:"id"`
	Title            string             `bson:"title" json:"title"`
	Description      string             `bson:"description" json:"description"`
	CreatorID        string             `bson:"creatorId" json:"creatorId"`
	CreatorName      string             `bson:"creatorName" json:"creatorName"`
	StartTime        time.Time          `bson:"startTime" json:"startTime"`
	EndTime          time.Time          `bson:"endTime" json:"endTime"`
	Latitude         float64            `bson:"latitude" json:"latitude"`
	Longitude        float64            `bson:"longitude" json:"longitude"`
	LocationName     string             `bson:"locationName" json:"locationName"`
	IsGpsEvent       bool               `bson:"isGpsEvent" json:"isGpsEvent"`
	RequiresApproval bool               `bson:"requiresApproval" json:"requiresApproval"`
	MaxAttendees     int                `bson:"maxAttendees" json:"maxAttendees"`
	Attendees        []Attendee         `bson:"attendees" json:"attendees"`
	CreatedAt        time.Time          `bson:"createdAt" json:"createdAt"`
}
