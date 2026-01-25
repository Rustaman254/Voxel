import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/event_model.dart';
import '../../domain/repositories/world_repository.dart';
import 'package:uuid/uuid.dart';

import 'world_controller.dart';

class EventNotifier extends StateNotifier<List<VoxelEvent>> {
  final WorldRepository _repository;

  EventNotifier(this._repository) : super([]) {
    _init();
  }

  void _init() {
    _repository.subscribeEventsList().listen((list) {
      final events = list.map((e) => VoxelEvent.fromJson(e)).toList();
      state = events;
    });

    _repository.subscribeEvents().listen((data) {
      final newEvent = VoxelEvent.fromJson(data);
      if (!state.any((e) => e.id == newEvent.id)) {
        state = [...state, newEvent];
      }
    });
  }

  void addEvent(String title, String description, double x, double y, String creatorId, {
    double ticketPrice = 0.0, 
    bool hasTickets = false,
    DateTime? startTime,
    String voxelTheme = 'CLASSIC',
  }) {
    final newEvent = VoxelEvent(
      id: const Uuid().v4(),
      title: title,
      description: description,
      x: x,
      y: y,
      creatorId: creatorId,
      startTime: startTime ?? DateTime.now().add(const Duration(hours: 1)),
      ticketPrice: ticketPrice,
      hasTickets: hasTickets,
      voxelTheme: voxelTheme,
    );
    
    // Instead of local-only, we send to repo. 
    // The repositoy/server will broadcast it back to us and others.
    _repository.createEvent(newEvent.toJson());
  }

  void removeEvent(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

final eventProvider = StateNotifierProvider<EventNotifier, List<VoxelEvent>>((ref) {
  final repo = ref.watch(worldRepositoryProvider);
  return EventNotifier(repo);
});
