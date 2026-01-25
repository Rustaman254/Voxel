import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/socket_world_repository.dart';
import 'world_controller.dart'; 
import 'auth_notifier.dart';

class GameSession {
  final String id;
  final String hostId;
  final String gameType;
  final String state; // LOBBY, PLAYING, FINISHED
  final List<String> players;

  GameSession({
    required this.id,
    required this.hostId,
    required this.gameType,
    required this.state,
    required this.players,
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      id: json['id'],
      hostId: json['hostId'],
      gameType: json['gameType'],
      state: json['state'],
      players: List<String>.from(json['players'] ?? []),
    );
  }
}

// 1. Notifier for the session the user is CURRENTLY playing in
class GameSessionNotifier extends StateNotifier<GameSession?> {
  final SocketWorldRepository _repository;
  final String? _myUserId;

  GameSessionNotifier(this._repository, this._myUserId) : super(null) {
    _repository.subscribeSessionUpdates().listen((data) {
      final session = GameSession.fromJson(data);
      // Only track if I am in the players list
      if (_myUserId != null && session.players.contains(_myUserId)) {
        state = session;
      } else {
        // If I was in it and now I'm not (kicked or left), or if I never was
        if (state?.id == session.id) {
           state = null;
        }
      }
    });
  }

  void createSession(String gameType) {
    _repository.createSession(gameType);
  }

  void joinSession(String sessionId) {
    _repository.joinSession(sessionId);
  }

  void startGame() {
    if (state != null) {
      _repository.startGame(state!.id);
    }
  }
}

final gameSessionProvider = StateNotifierProvider<GameSessionNotifier, GameSession?>((ref) {
  final repo = ref.watch(worldRepositoryProvider) as SocketWorldRepository;
  final user = ref.watch(authProvider).value;
  return GameSessionNotifier(repo, user?.id);
});

// 2. Notifier for ALL available sessions (Lobby list)
class AvailableSessionsNotifier extends StateNotifier<List<GameSession>> {
  final SocketWorldRepository _repository;

  AvailableSessionsNotifier(this._repository) : super([]) {
    _repository.subscribeSessionUpdates().listen((data) {
      final session = GameSession.fromJson(data);
      
      if (session.state == 'FINISHED') {
        // Remove
        state = state.where((s) => s.id != session.id).toList();
      } else {
        // Add or Update
        final index = state.indexWhere((s) => s.id == session.id);
        if (index != -1) {
          // Update existing
          final updated = List<GameSession>.from(state);
          updated[index] = session;
          state = updated;
        } else {
          // Add new
          state = [...state, session];
        }
      }
    });
  }
}

final availableSessionsProvider = StateNotifierProvider<AvailableSessionsNotifier, List<GameSession>>((ref) {
  final repo = ref.watch(worldRepositoryProvider) as SocketWorldRepository;
  return AvailableSessionsNotifier(repo);
});
