import 'dart:async';
import 'dart:math';

import '../../domain/entities/avatar_position.dart';
import '../../domain/repositories/world_repository.dart';

class MockWorldRepository implements WorldRepository {
  final _positionController = StreamController<List<AvatarPosition>>.broadcast();
  final List<AvatarPosition> _mockUsers = [];
  Timer? _simulationTimer;
  final Random _rnd = Random();
  MockWorldRepository() {
    _initMockUsers();
  }

  void _initMockUsers() {
    // intrinsic parameters
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
        // Use 'adventurer' style for Memoji-like 3D look
        avatarUrl: 'https://api.dicebear.com/9.x/adventurer/png?seed=${seeds[i % seeds.length]}&backgroundColor=transparent',
      ));
    }
  }

  void _startSimulation() {
    _stopSimulation();
    // No random movement requested. Just emit static users.
    // _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) { ... });
    _positionController.add(List.from(_mockUsers));
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
  }

  @override
  Future<void> connect(String userId) async {
    // Simulate network delay
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
    // In a real app, we'd send this to server.
    // For mock, we effectively do nothing or could echo it back.
    // We won't add 'myself' to _mockUsers to avoid double rendering if UI handles local user separately.
    await Future.delayed(const Duration(milliseconds: 10)); // tiny latency
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
}
