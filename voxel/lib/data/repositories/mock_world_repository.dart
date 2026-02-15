import 'dart:async';
import 'dart:math';

import '../../domain/entities/avatar_position.dart';
import '../../domain/repositories/world_repository.dart';

class MockWorldRepository implements WorldRepository {
  final _positionController = StreamController<List<AvatarPosition>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final List<AvatarPosition> _mockUsers = [];
  Timer? _simulationTimer;
  final Random _rnd = Random();
  String? _userId;

  MockWorldRepository() {
    _initMockUsers();
  }

  void _initMockUsers() {
    final userCount = 5;
    final startX = 500.0;
    final startY = 500.0;
    final seeds = ['Felix', 'Aneka', 'Bob', 'Jack', 'Milly', 'Zoe', 'Alexander', 'Willow', 'Oliver', 'Leo'];
    for (int i = 0; i < userCount; i++) {
      _mockUsers.add(AvatarPosition(
        userId: 'user_$i',
        x: startX + _rnd.nextDouble() * 200 - 100,
        y: startY + _rnd.nextDouble() * 200 - 100,
        updatedAt: DateTime.now(),
        avatarUrl: 'https://api.dicebear.com/9.x/adventurer/png?seed=${seeds[i % seeds.length]}&backgroundColor=transparent',
      ));
    }
  }

  void _startSimulation() {
    _stopSimulation();
    _positionController.add(List.from(_mockUsers));
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
  }

  @override
  Future<void> connect(String userId, {String? token}) async {
    _userId = userId;
    await Future.delayed(const Duration(milliseconds: 500));
    _startSimulation();
  }

  @override
  Future<void> disconnect() async {
    _stopSimulation();
  }

  @override
  Stream<List<AvatarPosition>> subscribePositions() {
    return _positionController.stream;
  }

  @override
  Future<void> updateMyPosition(AvatarPosition position) async {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  @override
  void createEvent(Map<String, dynamic> eventData) {}

  @override
  void sendAudio(List<int> data) {}

  @override
  Stream<Map<String, dynamic>> subscribeAudio() => const Stream.empty();

  @override
  Stream<Map<String, dynamic>> subscribeEvents() => const Stream.empty();

  @override
  Stream<List<dynamic>> subscribeEventsList() => Stream.value([]);

  @override
  AvatarPosition? getPeerPosition(String userId) => null;

  @override
  AvatarPosition? getMyPosition() => null;

  @override
  void sendSignaling(String type, String targetId, dynamic data) {}

  @override
  Stream<Map<String, dynamic>> subscribeSignaling() => const Stream.empty();

  @override
  Future<void> joinEvent(String eventId) async {}

  @override
  Future<void> leaveEvent(String eventId) async {}

  @override
  Stream<Map<String, dynamic>> subscribeNotifications() {
    return _notificationController.stream;
  }

  @override
  Future<void> respondToFriendRequest(String requestId, String response) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }

  @override
  void sendMessage(Map<String, dynamic> data) {}
}
