import '../entities/avatar_position.dart';

abstract class WorldRepository {
  /// Connect to the world server
  Future<void> connect(String userId, {String? token});

  /// Disconnect from the world server
  Future<void> disconnect();

  /// Stream of position updates from all users
  Stream<List<AvatarPosition>> subscribePositions();

  /// Update my own position
  Future<void> updateMyPosition(AvatarPosition position);

  /// Send audio data
  void sendAudio(List<int> data);

  /// Stream of incoming audio packets: Map with 'userId' and 'data'
  Stream<Map<String, dynamic>> subscribeAudio();

  /// Create a new event
  void createEvent(Map<String, dynamic> eventData);

  /// Stream of new events
  Stream<Map<String, dynamic>> subscribeEvents();

  /// Stream of initial events list
  Stream<List<dynamic>> subscribeEventsList();

  /// Get current cached position of a peer
  AvatarPosition? getPeerPosition(String userId);

  /// Get my own current cached position
  AvatarPosition? getMyPosition();

  /// Stream of incoming WebRTC signaling messages
  Stream<Map<String, dynamic>> subscribeSignaling();

  /// Join an event (attendance)
  Future<void> joinEvent(String eventId);

  /// Leave an event
  Future<void> leaveEvent(String eventId);

  /// Stream of notifications (messages, friend requests)
  Stream<Map<String, dynamic>> subscribeNotifications();

  /// Respond to a friend request ('accept' or 'reject')
  Future<void> respondToFriendRequest(String requestId, String response);

  /// Send a generic message to the server
  void sendMessage(Map<String, dynamic> data);
}
