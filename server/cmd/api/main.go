package main

import (
	"context"
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
	r := gin.Default()
	r.Use(CORSMiddleware())

	// Data Routes
	r.POST("/login", func(c *gin.Context) {
		var req data.AuthRequest
		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}

		// Logic: Find user by Username. If exists, return. If not, create.
		collection := data.GetCollection("users")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		var user data.User
		err := collection.FindOne(ctx, bson.M{"username": req.Username}).Decode(&user)
		if err == nil {
			// Found, update avatar if changed?
			// For now just return existing
			c.JSON(http.StatusOK, data.AuthResponse{
				Token:  user.ID.Hex(),
				UserID: user.ID.Hex(),
			})
			return
		}

		// Create New
		newUser := data.User{
			ID:        primitive.NewObjectID(),
			Username:  req.Username,
			AvatarUrl: req.AvatarUrl,
			CreatedAt: time.Now(),
			LastSeen:  time.Now(),
			X:         500, // Default start
			Y:         500,
		}
		_, err = collection.InsertOne(ctx, newUser)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
			return
		}

		c.JSON(http.StatusOK, data.AuthResponse{
			Token:  newUser.ID.Hex(),
			UserID: newUser.ID.Hex(),
		})
	})

	// WebSocket Route
	r.GET("/ws", func(c *gin.Context) {
		log.Printf("👣 /ws endpoint hit! Headers: %v", c.Request.Header)
		userId := c.Query("userId")
		if userId == "" {
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
