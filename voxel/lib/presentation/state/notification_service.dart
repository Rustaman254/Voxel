import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/world_repository.dart';
import '../../data/services/chat_database_service.dart';
import 'auth_notifier.dart';
import 'world_controller.dart';

// Notification Models
class AppNotification {
  final String id;
  final String type; // 'message', 'friend_request', 'room_joined', 'room_left', 'room_message', 'event_updated', 'event_participant'
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final NotificationPriority priority;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.data,
    this.priority = NotificationPriority.normal,
    this.isRead = false,
  });
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

class NotificationService extends StateNotifier<List<AppNotification>> {
  final WorldRepository _worldRepository;
  final Ref _ref;
  final ChatDatabaseService _chatDatabaseService;
  StreamSubscription? _socketSubscription;

  NotificationService(this._worldRepository, this._ref) 
      : _chatDatabaseService = ChatDatabaseService(),
        super([]) {
    _initListeners();
  }

  void _initListeners() {
    _socketSubscription?.cancel();
    _socketSubscription = _worldRepository.subscribeNotifications().listen((data) {
      handleIncomingMessage(data);
    });
  }
  
  void handleIncomingMessage(Map<String, dynamic> message) {
    final type = message['type'];
    
    debugPrint('📬 Notification received: $type');
    
    switch (type) {
      case 'message_received':
        _handleMessageNotification(message);
        break;
      case 'friend_request':
        _handleFriendRequestNotification(message);
        break;
      case 'room_joined':
        _handleRoomJoinedNotification(message);
        break;
      case 'room_left':
        _handleRoomLeftNotification(message);
        break;
      case 'room_message':
        _handleRoomMessageNotification(message);
        break;
      case 'event_updated':
        _handleEventUpdatedNotification(message);
        break;
      case 'event_participant_joined':
        _handleEventParticipantNotification(message, joined: true);
        break;
      case 'event_participant_left':
        _handleEventParticipantNotification(message, joined: false);
        break;
      default:
        debugPrint('⚠️ Unknown notification type: $type');
    }
  }

  void _handleMessageNotification(Map<String, dynamic> message) {
    final payload = message['payload'] ?? message;
    final senderId = payload['senderId'] ?? payload['senderID'] ?? '';
    final content = payload['content'] ?? 'You received a message';
    final messageId = payload['id']?.toString() ?? DateTime.now().toString();
    
    // SAVE TO DATABASE
    final currentUserId = _ref.read(authProvider).user?.id;
    if (currentUserId != null && senderId.isNotEmpty) {
      _chatDatabaseService.saveMessage(ChatMessage(
        id: messageId,
        senderId: senderId,
        receiverId: currentUserId,
        message: content,
        timestamp: DateTime.now(),
        isRead: false,
      ));
    }

    final notification = AppNotification(
      id: messageId,
      type: 'message',
      title: 'New Message',
      body: content,
      timestamp: DateTime.now(),
      data: {
        'senderId': senderId,
        'content': content,
        ...payload,
      },
      priority: NotificationPriority.high,
    );
    addNotification(notification);
  }

  void _handleFriendRequestNotification(Map<String, dynamic> message) {
    final payload = message['payload'] ?? message;
    final senderId = payload['senderId'] ?? payload['senderID'] ?? '';
    final senderName = payload['senderName'] ?? 'Someone';
    
    final notification = AppNotification(
      id: payload['id']?.toString() ?? DateTime.now().toString(),
      type: 'friend_request',
      title: 'Friend Request',
      body: '$senderName sent you a friend request',
      timestamp: DateTime.now(),
      data: {
        'senderId': senderId,
        'senderName': senderName,
        ...payload,
      },
      priority: NotificationPriority.high,
    );
    addNotification(notification);
  }

  void _handleRoomJoinedNotification(Map<String, dynamic> message) {
    final payload = message['payload'] ?? message;
    final userId = payload['userId'] ?? '';
    final username = payload['username'] ?? 'Someone';
    final roomId = payload['roomId'] ?? '';
    
    final notification = AppNotification(
      id: DateTime.now().toString(),
      type: 'room_joined',
      title: 'Room Activity',
      body: '$username joined the room',
      timestamp: DateTime.now(),
      data: {
        'userId': userId,
        'username': username,
        'roomId': roomId,
        ...payload,
      },
      priority: NotificationPriority.normal,
    );
    addNotification(notification);
  }

  void _handleRoomLeftNotification(Map<String, dynamic> message) {
    final payload = message['payload'] ?? message;
    final userId = payload['userId'] ?? '';
    final username = payload['username'] ?? 'Someone';
    final roomId = payload['roomId'] ?? '';
    
    final notification = AppNotification(
      id: DateTime.now().toString(),
      type: 'room_left',
      title: 'Room Activity',
      body: '$username left the room',
      timestamp: DateTime.now(),
      data: {
        'userId': userId,
        'username': username,
        'roomId': roomId,
        ...payload,
      },
      priority: NotificationPriority.low,
    );
    addNotification(notification);
  }

  void _handleRoomMessageNotification(Map<String, dynamic> message) {
    final payload = message['payload'] ?? message;
    final roomId = payload['roomId'] ?? '';
    final roomName = payload['roomName'] ?? 'Room';
    final content = payload['content'] ?? 'New message in room';
    
    final notification = AppNotification(
      id: DateTime.now().toString(),
      type: 'room_message',
      title: 'Room Message',
      body: '$roomName: $content',
      timestamp: DateTime.now(),
      data: {
        'roomId': roomId,
        'roomName': roomName,
        'content': content,
        ...payload,
      },
      priority: NotificationPriority.normal,
    );
    addNotification(notification);
  }

  void _handleEventUpdatedNotification(Map<String, dynamic> message) {
    final payload = message['payload'] ?? message;
    final eventId = payload['eventId'] ?? payload['id'] ?? '';
    final eventTitle = payload['title'] ?? 'Event';
    
    final notification = AppNotification(
      id: DateTime.now().toString(),
      type: 'event_updated',
      title: 'Event Update',
      body: '$eventTitle has been updated',
      timestamp: DateTime.now(),
      data: {
        'eventId': eventId,
        'eventTitle': eventTitle,
        ...payload,
      },
      priority: NotificationPriority.normal,
    );
    addNotification(notification);
  }

  void _handleEventParticipantNotification(Map<String, dynamic> message, {required bool joined}) {
    final payload = message['payload'] ?? message;
    final userId = payload['userId'] ?? '';
    final username = payload['username'] ?? 'Someone';
    final eventId = payload['eventId'] ?? '';
    final eventTitle = payload['eventTitle'] ?? 'Event';
    
    final notification = AppNotification(
      id: DateTime.now().toString(),
      type: joined ? 'event_participant_joined' : 'event_participant_left',
      title: 'Event Activity',
      body: '$username ${joined ? "joined" : "left"} $eventTitle',
      timestamp: DateTime.now(),
      data: {
        'userId': userId,
        'username': username,
        'eventId': eventId,
        'eventTitle': eventTitle,
        ...payload,
      },
      priority: NotificationPriority.normal,
    );
    addNotification(notification);
  }

  void addNotification(AppNotification notification) {
    state = [notification, ...state];
    debugPrint('✅ Notification added: ${notification.type} - ${notification.title}');
  }

  void markAsRead(String id) {
    state = state.map((n) {
      if (n.id == id) {
        n.isRead = true;
      }
      return n;
    }).toList();
  }
  
  void clearNotification(String id) {
    state = state.where((n) => n.id != id).toList();
  }
  
  void clearAll() {
    state = [];
  }
  
  void clearByType(String type) {
    state = state.where((n) => n.type != type).toList();
  }
  
  int get unreadCount => state.where((n) => !n.isRead).length;
  
  int unreadCountByType(String type) {
    return state.where((n) => n.type == type && !n.isRead).length;
  }
  
  List<AppNotification> getByType(String type) {
    return state.where((n) => n.type == type).toList();
  }
  
  List<AppNotification> getByPriority(NotificationPriority priority) {
    return state.where((n) => n.priority == priority).toList();
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    super.dispose();
  }
}

final notificationServiceProvider = StateNotifierProvider<NotificationService, List<AppNotification>>((ref) {
  final repo = ref.watch(worldRepositoryProvider);
  return NotificationService(repo, ref);
});
