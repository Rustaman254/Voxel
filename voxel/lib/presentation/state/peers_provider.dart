import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../domain/entities/avatar_position.dart';
import '../../domain/services/voice_chat_service.dart';
import '../../data/services/webrtc_voice_service.dart';
import 'world_controller.dart';
import 'auth_notifier.dart';

// Stream of all other users' positions
final peersStreamProvider = StreamProvider<List<AvatarPosition>>((ref) {
  final repo = ref.watch(worldRepositoryProvider);
  return repo.subscribePositions();
});

final voiceChatServiceProvider = Provider<VoiceChatService>((ref) {
  final repo = ref.watch(worldRepositoryProvider);
  final userId = ref.watch(authProvider).value?.id ?? 'anon';
  
  final service = WebRtcVoiceService(repo, userId);
  
  // Ensure proper disposal when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

final voiceStateProvider = StreamProvider<VoiceChatState>((ref) {
  final service = ref.watch(voiceChatServiceProvider);
  return service.state;
});

// 1. Separate provider to calculate the set of nearby user IDs
final nearbyPeersProvider = Provider<Set<String>>((ref) {
  final worldState = ref.watch(worldControllerProvider);
  final peersAsync = ref.watch(peersStreamProvider);
  final myPos = worldState.myPosition;

  if (myPos == null) return {};

  return peersAsync.maybeWhen(
    data: (peers) {
      final nearby = <String>{};
      const double proximityRadius = 400.0; // Larger for better testability

      for (final peer in peers) {
        if (peer.userId == myPos.userId) continue;
        final dist = sqrt(pow(peer.x - myPos.x, 2) + pow(peer.y - myPos.y, 2));
        if (dist <= proximityRadius) {
          nearby.add(peer.userId);
        }
      }
      return nearby;
    },
    orElse: () => {},
  );
});

// 2. Logic to act on changes in nearby peers
final proximityLogicProvider = Provider<void>((ref) {
  final voiceService = ref.read(voiceChatServiceProvider);
  final audioPlayer = AudioPlayer();
  
  ref.onDispose(() {
    audioPlayer.dispose();
  });
  
  // Listen to changes and only act if the set is different
  ref.listen<Set<String>>(nearbyPeersProvider, (previous, next) {
    // Check if the set of nearby users actually changed (content-wise)
    final prevSet = previous ?? {};
    final hasChanged = next.length != prevSet.length || !next.every(prevSet.contains);

    if (!hasChanged) return;

    // Detect joins and leaves
    final joined = next.difference(prevSet);
    final left = prevSet.difference(next);

    // Play join chime for new users
    if (joined.isNotEmpty) {
      audioPlayer.play(AssetSource('sounds/join.wav'), volume: 0.5);
      voiceService.joinGroup(next);
    }

    // Play leave chime for departed users
    if (left.isNotEmpty) {
      audioPlayer.play(AssetSource('sounds/leave.wav'), volume: 0.5);
    }

    // Update voice service
    if (next.isEmpty) {
      voiceService.leaveGroup();
    }
  }, fireImmediately: true);
});
