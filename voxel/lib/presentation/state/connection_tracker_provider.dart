import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'peers_provider.dart';
import 'room_controller.dart';

/// Tracks all active connections across different contexts
class ConnectionTracker {
  final Set<String> friendsOnline;
  final Set<String> roomMembers;
  final Set<String> eventParticipants;
  
  const ConnectionTracker({
    this.friendsOnline = const {},
    this.roomMembers = const {},
    this.eventParticipants = const {},
  });
  
  int get totalConnections {
    final allConnections = <String>{
      ...friendsOnline,
      ...roomMembers,
      ...eventParticipants,
    };
    return allConnections.length;
  }
  
  int get friendsCount => friendsOnline.length;
  int get roomMembersCount => roomMembers.length;
  int get eventParticipantsCount => eventParticipants.length;
  
  ConnectionTracker copyWith({
    Set<String>? friendsOnline,
    Set<String>? roomMembers,
    Set<String>? eventParticipants,
  }) {
    return ConnectionTracker(
      friendsOnline: friendsOnline ?? this.friendsOnline,
      roomMembers: roomMembers ?? this.roomMembers,
      eventParticipants: eventParticipants ?? this.eventParticipants,
    );
  }
}

final connectionTrackerProvider = Provider<ConnectionTracker>((ref) {
  // Watch peers for friends
  final peers = ref.watch(peersProvider);
  final peerIds = peers.map((p) => p.userId).toSet();
  
  // Watch room state for room members
  final roomState = ref.watch(roomControllerProvider);
  final memberIds = roomState.currentRoom?.members.map((m) => m.userId).toSet() ?? <String>{};
  
  // TODO: Add event participants tracking when event controller is available
  final eventParticipantIds = <String>{};
  
  final tracker = ConnectionTracker(
    friendsOnline: peerIds,
    roomMembers: memberIds,
    eventParticipants: eventParticipantIds,
  );
  
  debugPrint('👥 Total connections: ${tracker.totalConnections} (Friends: ${tracker.friendsCount}, Room: ${tracker.roomMembersCount}, Event: ${tracker.eventParticipantsCount})');
  
  return tracker;
});

final connectionCountProvider = Provider<int>((ref) {
  final tracker = ref.watch(connectionTrackerProvider);
  return tracker.totalConnections;
});
