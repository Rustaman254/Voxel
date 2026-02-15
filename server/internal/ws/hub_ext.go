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

// HandleFriendRequestResponse handles accepting or rejecting friend requests
func (h *Hub) HandleFriendRequestResponse(payload map[string]interface{}, client *Client) {
	reqIDStr, ok := payload["requestId"].(string)
	response, ok2 := payload["response"].(string) // "accept" or "reject"
	if !ok || !ok2 || reqIDStr == "" {
		return
	}

	collection := data.GetCollection("friend_requests")
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	reqID, _ := primitive.ObjectIDFromHex(reqIDStr)

	// Update request status
	update := bson.M{"$set": bson.M{"status": response, "updatedAt": time.Now()}}

	// Find the request first to get sender/receiver
	var req data.FriendRequest
	err := collection.FindOne(ctx, bson.M{"_id": reqID}).Decode(&req)
	if err != nil {
		log.Printf("❌ Friend request not found: %v", err)
		return
	}

	// Validate receiver is the one responding
	if req.ReceiverID != client.UserID {
		log.Printf("❌ Unauthorized response to friend request")
		return
	}

	_, err = collection.UpdateOne(ctx, bson.M{"_id": reqID}, update)
	if err != nil {
		log.Printf("❌ Failed to update friend request: %v", err)
		return
	}

	senderID := req.SenderID
	receiverID := req.ReceiverID

	log.Printf("Friend Request %s responded by %s: %s", reqIDStr, receiverID, response)

	if response == "accept" {
		usersCollection := data.GetCollection("users")

		// Add receiver to sender's friends
		sID, _ := primitive.ObjectIDFromHex(senderID)
		_, err = usersCollection.UpdateOne(ctx, bson.M{"_id": sID}, bson.M{"$addToSet": bson.M{"friends": receiverID}})

		// Add sender to receiver's friends
		rID, _ := primitive.ObjectIDFromHex(receiverID)
		_, err = usersCollection.UpdateOne(ctx, bson.M{"_id": rID}, bson.M{"$addToSet": bson.M{"friends": senderID}})

		if err != nil {
			log.Printf("❌ Failed to update friends list: %v", err)
		}
	}

	// Notify the original sender
	msg, _ := json.Marshal(Message{
		Type: "friend_request_response",
		Payload: map[string]interface{}{
			"requestId":   reqIDStr,
			"response":    response,
			"responderId": client.UserID,
		},
	})
	h.sendToUser(senderID, msg)
}
