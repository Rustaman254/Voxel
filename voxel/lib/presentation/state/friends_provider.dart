import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/world_repository.dart';
import 'world_controller.dart';

class FriendRequest {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final DateTime timestamp;

  FriendRequest({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.timestamp,
  });

  factory FriendRequest.fromJson(Map<String, dynamic> json) {
    return FriendRequest(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Unknown',
      senderAvatar: json['senderAvatar'],
      timestamp: json['timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp']) 
          : DateTime.now(),
    );
  }
}

class Friend {
  final String id;
  final String username;
  final String? avatarUrl;
  final bool isOnline;

  Friend({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.isOnline = false,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      id: json['id'] ?? '',
      username: json['username'] ?? 'Unknown',
      avatarUrl: json['avatarUrl'],
      isOnline: json['isOnline'] ?? false,
    );
  }
}

class FriendsState {
  final List<Friend> friends;
  final List<FriendRequest> pendingRequests;
  final bool isLoading;

  FriendsState({
    this.friends = const [],
    this.pendingRequests = const [],
    this.isLoading = false,
  });

  FriendsState copyWith({
    List<Friend>? friends,
    List<FriendRequest>? pendingRequests,
    bool? isLoading,
  }) {
    return FriendsState(
      friends: friends ?? this.friends,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FriendsNotifier extends StateNotifier<FriendsState> {
  final WorldRepository _repository;
  StreamSubscription? _subscription;

  FriendsNotifier(this._repository) : super(FriendsState()) {
    _initListeners();
  }

  void _initListeners() {
    _subscription = _repository.subscribeNotifications().listen((data) {
      if (data['type'] == 'friend_request') {
        _handleFriendRequest(data);
      }
    });
  }

  void _handleFriendRequest(Map<String, dynamic> data) {
      try {
        final payload = data['payload'] ?? data;
        final request = FriendRequest(
          id: payload['id']?.toString() ?? DateTime.now().toString(),
          senderId: payload['senderId'] ?? payload['senderID'] ?? '',
          senderName: payload['senderName'] ?? 'Unknown',
          senderAvatar: payload['senderAvatar'],
          timestamp: DateTime.now(),
        );
        addIncomingRequest(request);
      } catch (e) {
        debugPrint('Error parsing friend request: $e');
      }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> loadFriends() async {
    // In a real app, this would fetch from API
    // For now, we'll simulate or use what we have
    // state = state.copyWith(isLoading: true);
    // try {
    //   final friends = await _repository.getFriends();
    //   state = state.copyWith(friends: friends, isLoading: false);
    // } catch (e) {
    //   state = state.copyWith(isLoading: false);
    // }
  }

  Future<void> sendFriendRequest(String userId) async {
    try {
      // Use the repository method (which we'll add) or raw socket
      // (_repository as dynamic).sendFriendRequest(userId); 
      // For now, we'll assume the socket repository has a generic sendMessage or we add a specific one
       (_repository as dynamic).sendMessage({
        'type': 'send_friend_request',
        'payload': {'targetUserId': userId}
      });
      debugPrint('Friend request sent to $userId');
    } catch (e) {
      debugPrint('Error sending friend request: $e');
    }
  }

  Future<void> respondToRequest(String requestId, bool accept) async {
    try {
      await _repository.respondToFriendRequest(requestId, accept ? 'accept' : 'reject');
      
      if (accept) {
        try {
          final request = state.pendingRequests.firstWhere((r) => r.id == requestId);
          final newFriend = Friend(
            id: request.senderId,
            username: request.senderName,
            avatarUrl: request.senderAvatar,
            isOnline: true, 
          );
          // Check if already exists
          if (!state.friends.any((f) => f.id == newFriend.id)) {
             state = state.copyWith(
                friends: [...state.friends, newFriend],
             );
          }
        } catch (e) {
          debugPrint('Could not find request details for accepted friend: $e');
        }
      }
      
      // Remove request
      state = state.copyWith(
        pendingRequests: state.pendingRequests.where((r) => r.id != requestId).toList(),
      );
    } catch (e) {
      debugPrint('Error responding to friend request: $e');
    }
  }

  void addIncomingRequest(FriendRequest request) {
    if (state.pendingRequests.any((r) => r.id == request.id)) return;
    state = state.copyWith(
      pendingRequests: [...state.pendingRequests, request],
    );
  }
  
  void addFriend(Friend friend) {
    if (state.friends.any((f) => f.id == friend.id)) return;
    state = state.copyWith(
      friends: [...state.friends, friend],
    );
  }
}

final friendsProvider = StateNotifierProvider<FriendsNotifier, FriendsState>((ref) {
  final repo = ref.watch(worldRepositoryProvider);
  return FriendsNotifier(repo);
});
