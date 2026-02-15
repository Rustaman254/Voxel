package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"go.mongodb.org/mongo-driver/bson"
	"go.mongodb.org/mongo-driver/bson/primitive"

	"voxel-server/internal/data"
	"voxel-server/internal/ws"
)

func VerboseLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		raw := c.Request.URL.RawQuery

		// Read and restore the body so it can be read again by the handler
		var bodyBytes []byte
		if c.Request.Body != nil {
			bodyBytes, _ = io.ReadAll(c.Request.Body)
		}
		c.Request.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

		log.Printf("📥 [%s] %s %s | Body: %s", c.Request.Method, path, raw, string(bodyBytes))

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()
		log.Printf("📤 [%d] %s | Latency: %v", status, path, latency)
	}
}

func main() {
	// 1. Env / Config
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb+srv://ofury47_db_user:XiA0DGObvu3AtumG@cluster0.aio4npr.mongodb.net/?appName=Cluster0"
	}

	// 2. Connect DB
	data.ConnectMongo(mongoURI)

	// 3. Start WS Hub
	hub := ws.NewHub()
	go hub.Run()

	// 4. Gin Router
	r := gin.New()

	// Configure trusted proxies (set to nil if not behind a proxy, or specify proxy IPs)
	// For local development, we trust all proxies. In production, specify exact IPs.
	r.SetTrustedProxies(nil)

	r.Use(VerboseLogger())
	r.Use(gin.Recovery())
	r.Use(CORSMiddleware())

	// Auth Routes
	r.POST("/api/auth/signup", func(c *gin.Context) {
		var req data.AuthRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request format"})
			return
		}

		// Validate required fields
		if req.Email == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email is required"})
			return
		}
		if req.Password == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Password is required"})
			return
		}
		if req.Username == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Username is required"})
			return
		}

		// Validate password length
		if len(req.Password) < 6 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Password must be at least 6 characters"})
			return
		}

		collection := data.GetCollection("users")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Check if email already exists
		var existingUser data.User
		err := collection.FindOne(ctx, bson.M{"email": req.Email}).Decode(&existingUser)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "This email is already registered. Please login instead."})
			return
		}

		// Check if username already exists
		err = collection.FindOne(ctx, bson.M{"username": req.Username}).Decode(&existingUser)
		if err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "This username is already taken. Please choose another."})
			return
		}

		// Hash password
		hashedPassword, err := data.HashPassword(req.Password)
		if err != nil {
			log.Printf("❌ Password hashing failed: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to process password"})
			return
		}

		// Create new user
		newUser := data.User{
			ID:          primitive.NewObjectID(),
			Email:       req.Email,
			Username:    req.Username,
			DisplayName: req.DisplayName,
			Password:    hashedPassword,
			AvatarUrl:   req.AvatarUrl,
			CreatedAt:   time.Now(),
			LastSeen:    time.Now(),
			X:           500, // Default start
			Y:           500,
		}

		// Set display name to username if not provided
		if newUser.DisplayName == "" {
			newUser.DisplayName = req.Username
		}

		log.Printf("👤 Creating new user: %s (Email: %s)", newUser.Username, newUser.Email)
		_, err = collection.InsertOne(ctx, newUser)
		if err != nil {
			log.Printf("❌ Failed to insert user: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create account. Please try again."})
			return
		}

		// Generate real JWT token
		token, err := data.GenerateToken(newUser.ID.Hex())
		if err != nil {
			log.Printf("❌ Failed to generate token for %s: %v", newUser.ID.Hex(), err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Account created but login failed. Please try logging in."})
			return
		}

		log.Printf("✅ User created successfully: %s", newUser.ID.Hex())
		c.JSON(http.StatusCreated, data.AuthResponse{
			Token:       token,
			UserID:      newUser.ID.Hex(),
			Username:    newUser.Username,
			DisplayName: newUser.DisplayName,
			AvatarUrl:   newUser.AvatarUrl,
		})
	})

	r.POST("/api/auth/login", func(c *gin.Context) {
		var req data.AuthRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request format"})
			return
		}

		// Validate required fields
		if req.Email == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Email is required"})
			return
		}
		if req.Password == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Password is required"})
			return
		}

		collection := data.GetCollection("users")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		log.Printf("🔑 Verifying credentials for: %s", req.Email)
		// Find user by email
		var user data.User
		err := collection.FindOne(ctx, bson.M{"email": req.Email}).Decode(&user)
		if err != nil {
			log.Printf("⚠️ Login failed: User not found (%s)", req.Email)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Account not found. Please sign up first."})
			return
		}

		// Verify password
		if !data.CheckPasswordHash(req.Password, user.Password) {
			log.Printf("⚠️ Login failed: Invalid password for (%s)", req.Email)
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Incorrect password. Please try again."})
			return
		}

		// Update last seen
		_, err = collection.UpdateOne(
			ctx,
			bson.M{"_id": user.ID},
			bson.M{"$set": bson.M{"lastSeen": time.Now()}},
		)
		if err != nil {
			log.Printf("⚠️ Failed to update lastSeen for %s: %v", user.ID.Hex(), err)
		}

		// Generate real JWT token
		token, err := data.GenerateToken(user.ID.Hex())
		if err != nil {
			log.Printf("❌ Failed to generate token for %s: %v", user.ID.Hex(), err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Login failed. Please try again."})
			return
		}

		log.Printf("✅ Login successful: %s", user.ID.Hex())
		c.JSON(http.StatusOK, data.AuthResponse{
			Token:       token,
			UserID:      user.ID.Hex(),
			Username:    user.Username,
			DisplayName: user.DisplayName,
			AvatarUrl:   user.AvatarUrl,
		})
	})

	// Profile Update Route
	r.PUT("/api/user/profile", func(c *gin.Context) {
		// Get token from header
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization token required"})
			return
		}

		// Remove "Bearer " prefix if present
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		// Validate token
		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		var req struct {
			DisplayName string `json:"displayName"`
			AvatarUrl   string `json:"avatarUrl"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request format"})
			return
		}

		collection := data.GetCollection("users")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Convert string ID to ObjectID
		objID, err := primitive.ObjectIDFromHex(userID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
			return
		}

		// Update user profile
		update := bson.M{"$set": bson.M{}}
		if req.DisplayName != "" {
			update["$set"].(bson.M)["displayName"] = req.DisplayName
		}
		if req.AvatarUrl != "" {
			update["$set"].(bson.M)["avatarUrl"] = req.AvatarUrl
		}

		result, err := collection.UpdateOne(ctx, bson.M{"_id": objID}, update)
		if err != nil {
			log.Printf("❌ Failed to update profile for %s: %v", userID, err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
			return
		}

		if result.MatchedCount == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		log.Printf("✅ Profile updated for user: %s", userID)
		c.JSON(http.StatusOK, gin.H{
			"message":     "Profile updated successfully",
			"displayName": req.DisplayName,
			"avatarUrl":   req.AvatarUrl,
		})
	})

	// ==================== ROOM ENDPOINTS ====================

	// Create Room
	r.POST("/api/rooms", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		var req struct {
			Name        string  `json:"name"`
			Description string  `json:"description"`
			IsPrivate   bool    `json:"isPrivate"`
			X           float64 `json:"x"`
			Y           float64 `json:"y"`
			Latitude    float64 `json:"latitude"`
			Longitude   float64 `json:"longitude"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		if req.Name == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Room name is required"})
			return
		}

		// Get user info
		usersCollection := data.GetCollection("users")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		objID, _ := primitive.ObjectIDFromHex(userID)
		var user data.User
		err = usersCollection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		// Create room with creator as first member
		room := data.Room{
			ID:          primitive.NewObjectID(),
			Name:        req.Name,
			Description: req.Description,
			CreatorID:   userID,
			CreatedAt:   time.Now(),
			IsPrivate:   req.IsPrivate,
			X:           req.X,
			Y:           req.Y,
			Latitude:    req.Latitude,
			Longitude:   req.Longitude,
			Members: []data.RoomMember{
				{
					UserID:      userID,
					Username:    user.Username,
					AvatarUrl:   user.AvatarUrl,
					Role:        "creator",
					JoinedAt:    time.Now(),
					Permissions: []string{"speak", "invite", "kick", "edit", "manage"},
				},
			},
		}

		collection := data.GetCollection("rooms")
		_, err = collection.InsertOne(ctx, room)
		if err != nil {
			log.Printf("❌ Failed to create room: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create room"})
			return
		}

		log.Printf("✅ Room created: %s by %s", room.Name, user.Username)
		c.JSON(http.StatusCreated, room)
	})

	// List Rooms
	r.GET("/api/rooms", func(c *gin.Context) {
		collection := data.GetCollection("rooms")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Only show public rooms or rooms user is a member of
		cursor, err := collection.Find(ctx, bson.M{"isPrivate": false})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch rooms"})
			return
		}
		defer cursor.Close(ctx)

		var rooms []data.Room
		if err = cursor.All(ctx, &rooms); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode rooms"})
			return
		}

		c.JSON(http.StatusOK, rooms)
	})

	// Get Room Details
	r.GET("/api/rooms/:id", func(c *gin.Context) {
		roomID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(roomID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid room ID"})
			return
		}

		collection := data.GetCollection("rooms")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var room data.Room
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Room not found"})
			return
		}

		c.JSON(http.StatusOK, room)
	})

	// Update Room
	r.PUT("/api/rooms/:id", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		roomID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(roomID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid room ID"})
			return
		}

		var req struct {
			Name        string `json:"name"`
			Description string `json:"description"`
			IsPrivate   bool   `json:"isPrivate"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		collection := data.GetCollection("rooms")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Check if user is creator or has edit permission
		var room data.Room
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Room not found"})
			return
		}

		if room.CreatorID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only creator can edit room"})
			return
		}

		update := bson.M{"$set": bson.M{
			"name":        req.Name,
			"description": req.Description,
			"isPrivate":   req.IsPrivate,
		}}

		_, err = collection.UpdateOne(ctx, bson.M{"_id": objID}, update)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update room"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"message": "Room updated successfully"})
	})

	// Delete Room
	r.DELETE("/api/rooms/:id", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		roomID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(roomID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid room ID"})
			return
		}

		collection := data.GetCollection("rooms")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Check if user is creator
		var room data.Room
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Room not found"})
			return
		}

		if room.CreatorID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only creator can delete room"})
			return
		}

		_, err = collection.DeleteOne(ctx, bson.M{"_id": objID})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete room"})
			return
		}

		log.Printf("✅ Room deleted: %s", room.Name)
		c.JSON(http.StatusOK, gin.H{"message": "Room deleted successfully"})
	})

	// Add Member to Room
	r.POST("/api/rooms/:id/members", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		roomID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(roomID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid room ID"})
			return
		}

		var req struct {
			UserID string `json:"userId"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		collection := data.GetCollection("rooms")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Check if requester is creator or has invite permission
		var room data.Room
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Room not found"})
			return
		}

		if room.CreatorID != userID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only creator can add members"})
			return
		}

		// Get user to add
		usersCollection := data.GetCollection("users")
		userObjID, _ := primitive.ObjectIDFromHex(req.UserID)
		var newUser data.User
		err = usersCollection.FindOne(ctx, bson.M{"_id": userObjID}).Decode(&newUser)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		// Check if already a member
		for _, member := range room.Members {
			if member.UserID == req.UserID {
				c.JSON(http.StatusBadRequest, gin.H{"error": "User is already a member"})
				return
			}
		}

		// Add new member
		newMember := data.RoomMember{
			UserID:      req.UserID,
			Username:    newUser.Username,
			AvatarUrl:   newUser.AvatarUrl,
			Role:        "member",
			JoinedAt:    time.Now(),
			Permissions: []string{"speak"},
		}

		_, err = collection.UpdateOne(
			ctx,
			bson.M{"_id": objID},
			bson.M{"$push": bson.M{"members": newMember}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add member"})
			return
		}

		log.Printf("✅ Member added to room %s: %s", room.Name, newUser.Username)
		c.JSON(http.StatusOK, gin.H{"message": "Member added successfully"})
	})

	// Remove Member from Room
	r.DELETE("/api/rooms/:id/members/:userId", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		requestUserID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		roomID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(roomID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid room ID"})
			return
		}

		memberUserID := c.Param("userId")

		collection := data.GetCollection("rooms")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Check if requester is creator
		var room data.Room
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Room not found"})
			return
		}

		if room.CreatorID != requestUserID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only creator can remove members"})
			return
		}

		if memberUserID == room.CreatorID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Cannot remove creator"})
			return
		}

		_, err = collection.UpdateOne(
			ctx,
			bson.M{"_id": objID},
			bson.M{"$pull": bson.M{"members": bson.M{"userId": memberUserID}}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to remove member"})
			return
		}

		log.Printf("✅ Member removed from room %s", room.Name)
		c.JSON(http.StatusOK, gin.H{"message": "Member removed successfully"})
	})

	// Join Room
	r.POST("/api/rooms/:id/join", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		roomID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(roomID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid room ID"})
			return
		}

		collection := data.GetCollection("rooms")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Get room
		var room data.Room
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Room not found"})
			return
		}

		// Check if already a member
		for _, member := range room.Members {
			if member.UserID == userID {
				c.JSON(http.StatusOK, room) // Already a member, return room
				return
			}
		}

		// Get user info
		usersCollection := data.GetCollection("users")
		userObjID, _ := primitive.ObjectIDFromHex(userID)
		var user data.User
		err = usersCollection.FindOne(ctx, bson.M{"_id": userObjID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		// Add new member
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
			bson.M{"_id": objID},
			bson.M{"$push": bson.M{"members": newMember}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to join room"})
			return
		}

		// Get updated room
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch updated room"})
			return
		}

		log.Printf("✅ User %s joined room %s", user.Username, room.Name)
		c.JSON(http.StatusOK, room)
	})

	// Leave Room
	r.POST("/api/rooms/:id/leave", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		roomID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(roomID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid room ID"})
			return
		}

		collection := data.GetCollection("rooms")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Get room to check if user is creator
		var room data.Room
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&room)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Room not found"})
			return
		}

		if room.CreatorID == userID {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Creator cannot leave room. Delete the room instead."})
			return
		}

		_, err = collection.UpdateOne(
			ctx,
			bson.M{"_id": objID},
			bson.M{"$pull": bson.M{"members": bson.M{"userId": userID}}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to leave room"})
			return
		}

		log.Printf("✅ User %s left room %s", userID, room.Name)
		c.JSON(http.StatusOK, gin.H{"message": "Left room successfully"})
	})

	// ==================== EVENT ENDPOINTS ====================

	// Create Event
	r.POST("/api/events", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		var req struct {
			Title            string    `json:"title"`
			Description      string    `json:"description"`
			StartTime        time.Time `json:"startTime"`
			EndTime          time.Time `json:"endTime"`
			Latitude         float64   `json:"latitude"`
			Longitude        float64   `json:"longitude"`
			LocationName     string    `json:"locationName"`
			RequiresApproval bool      `json:"requiresApproval"`
			MaxAttendees     int       `json:"maxAttendees"`
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		if req.Title == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Event title is required"})
			return
		}

		// Get user info
		usersCollection := data.GetCollection("users")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		objID, _ := primitive.ObjectIDFromHex(userID)
		var user data.User
		err = usersCollection.FindOne(ctx, bson.M{"_id": objID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		event := data.EventModel{
			ID:               primitive.NewObjectID(),
			Title:            req.Title,
			Description:      req.Description,
			CreatorID:        userID,
			CreatorName:      user.DisplayName,
			StartTime:        req.StartTime,
			EndTime:          req.EndTime,
			Latitude:         req.Latitude,
			Longitude:        req.Longitude,
			LocationName:     req.LocationName,
			IsGpsEvent:       true,
			RequiresApproval: req.RequiresApproval,
			MaxAttendees:     req.MaxAttendees,
			Attendees:        []data.Attendee{},
			CreatedAt:        time.Now(),
		}

		collection := data.GetCollection("events")
		_, err = collection.InsertOne(ctx, event)
		if err != nil {
			log.Printf("❌ Failed to create event: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create event"})
			return
		}

		log.Printf("✅ Event created: %s by %s", event.Title, user.DisplayName)
		c.JSON(http.StatusCreated, event)
	})

	// List Events (GPS-based filtering)
	r.GET("/api/events", func(c *gin.Context) {
		collection := data.GetCollection("events")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		// Filter for GPS events only
		cursor, err := collection.Find(ctx, bson.M{"isGpsEvent": true})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch events"})
			return
		}
		defer cursor.Close(ctx)

		var events []data.EventModel
		if err = cursor.All(ctx, &events); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to decode events"})
			return
		}

		c.JSON(http.StatusOK, events)
	})

	// Get Event Details
	r.GET("/api/events/:id", func(c *gin.Context) {
		eventID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(eventID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
			return
		}

		collection := data.GetCollection("events")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var event data.EventModel
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&event)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

		c.JSON(http.StatusOK, event)
	})

	// Register for Event
	r.POST("/api/events/:id/register", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		eventID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(eventID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
			return
		}

		collection := data.GetCollection("events")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var event data.EventModel
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&event)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

		// Check if already registered
		for _, attendee := range event.Attendees {
			if attendee.UserID == userID {
				c.JSON(http.StatusBadRequest, gin.H{"error": "Already registered for this event"})
				return
			}
		}

		// Check max attendees
		if event.MaxAttendees > 0 && len(event.Attendees) >= event.MaxAttendees {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Event is full"})
			return
		}

		// Get user info
		usersCollection := data.GetCollection("users")
		userObjID, _ := primitive.ObjectIDFromHex(userID)
		var user data.User
		err = usersCollection.FindOne(ctx, bson.M{"_id": userObjID}).Decode(&user)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}

		// Determine initial status
		status := "approved"
		if event.RequiresApproval {
			status = "pending"
		}

		attendee := data.Attendee{
			UserID:       userID,
			Username:     user.Username,
			Email:        user.Email,
			AvatarUrl:    user.AvatarUrl,
			Status:       status,
			RegisteredAt: time.Now(),
		}

		_, err = collection.UpdateOne(
			ctx,
			bson.M{"_id": objID},
			bson.M{"$push": bson.M{"attendees": attendee}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to register"})
			return
		}

		log.Printf("✅ User %s registered for event: %s", user.Username, event.Title)
		c.JSON(http.StatusOK, gin.H{"message": "Registration successful", "status": status})
	})

	// Approve/Reject Attendee
	r.PUT("/api/events/:id/attendees/:userId", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		creatorID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		eventID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(eventID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
			return
		}

		attendeeUserID := c.Param("userId")

		var req struct {
			Status string `json:"status"` // approved or rejected
		}

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
			return
		}

		if req.Status != "approved" && req.Status != "rejected" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Status must be 'approved' or 'rejected'"})
			return
		}

		collection := data.GetCollection("events")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var event data.EventModel
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&event)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

		if event.CreatorID != creatorID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only event creator can approve attendees"})
			return
		}

		// Update attendee status
		_, err = collection.UpdateOne(
			ctx,
			bson.M{"_id": objID, "attendees.userId": attendeeUserID},
			bson.M{"$set": bson.M{"attendees.$.status": req.Status}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update attendee status"})
			return
		}

		log.Printf("✅ Attendee %s for event %s", req.Status, event.Title)
		c.JSON(http.StatusOK, gin.H{"message": "Attendee status updated"})
	})

	// Check-in to Event
	r.POST("/api/events/:id/checkin", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		userID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		eventID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(eventID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
			return
		}

		collection := data.GetCollection("events")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var event data.EventModel
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&event)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

		// Find attendee
		found := false
		for _, attendee := range event.Attendees {
			if attendee.UserID == userID {
				if attendee.Status != "approved" {
					c.JSON(http.StatusForbidden, gin.H{"error": "Registration not approved"})
					return
				}
				if attendee.CheckedInAt != nil {
					c.JSON(http.StatusBadRequest, gin.H{"error": "Already checked in"})
					return
				}
				found = true
				break
			}
		}

		if !found {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Not registered for this event"})
			return
		}

		// Update check-in time
		now := time.Now()
		_, err = collection.UpdateOne(
			ctx,
			bson.M{"_id": objID, "attendees.userId": userID},
			bson.M{"$set": bson.M{"attendees.$.checkedInAt": now}},
		)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check in"})
			return
		}

		log.Printf("✅ User checked in to event: %s", event.Title)
		c.JSON(http.StatusOK, gin.H{"message": "Checked in successfully", "checkedInAt": now})
	})

	// Get Attendance List
	r.GET("/api/events/:id/attendance", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		creatorID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		eventID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(eventID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
			return
		}

		collection := data.GetCollection("events")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var event data.EventModel
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&event)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

		if event.CreatorID != creatorID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only event creator can view attendance"})
			return
		}

		c.JSON(http.StatusOK, event.Attendees)
	})

	// Export Attendance (CSV)
	r.GET("/api/events/:id/attendance/export", func(c *gin.Context) {
		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization required"})
			return
		}
		if len(token) > 7 && token[:7] == "Bearer " {
			token = token[7:]
		}

		creatorID, err := data.ValidateToken(token)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
			return
		}

		eventID := c.Param("id")
		objID, err := primitive.ObjectIDFromHex(eventID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid event ID"})
			return
		}

		collection := data.GetCollection("events")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var event data.EventModel
		err = collection.FindOne(ctx, bson.M{"_id": objID}).Decode(&event)
		if err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Event not found"})
			return
		}

		if event.CreatorID != creatorID {
			c.JSON(http.StatusForbidden, gin.H{"error": "Only event creator can export attendance"})
			return
		}

		// Generate CSV
		csv := "Username,Email,Status,Registered At,Checked In At\n"
		for _, attendee := range event.Attendees {
			checkedIn := "Not checked in"
			if attendee.CheckedInAt != nil {
				checkedIn = attendee.CheckedInAt.Format("2006-01-02 15:04:05")
			}
			csv += fmt.Sprintf("%s,%s,%s,%s,%s\n",
				attendee.Username,
				attendee.Email,
				attendee.Status,
				attendee.RegisteredAt.Format("2006-01-02 15:04:05"),
				checkedIn,
			)
		}

		c.Header("Content-Type", "text/csv")
		c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=attendance_%s.csv", event.Title))
		c.String(http.StatusOK, csv)
	})

	// WebSocket Route
	r.GET("/ws", func(c *gin.Context) {
		log.Printf("👣 /ws endpoint hit! Headers: %v", c.Request.Header)
		userId := c.Query("userId")
		token := c.Query("token")

		if token != "" {
			validUserId, err := data.ValidateToken(token)
			if err != nil {
				log.Printf("❌ Invalid token for WS connection: %v", err)
				c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid token"})
				return
			}
			// If both are provided, they should match
			if userId != "" && userId != validUserId {
				log.Printf("⚠️ Token user (%s) doesn't match query user (%s)", validUserId, userId)
				// Prefer the token's user ID for security
				userId = validUserId
			} else if userId == "" {
				userId = validUserId
			}
		} else if userId == "" {
			// If no token and no userId, assign an anonymous ID
			userId = "anon_" + primitive.NewObjectID().Hex()
		}

		sessionId := c.Query("sessionId")
		ws.ServeWs(hub, c.Writer, c.Request, userId, sessionId)
	})

	// 5. Run
	log.Printf("Server starting on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal(err)
	}
}

func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
