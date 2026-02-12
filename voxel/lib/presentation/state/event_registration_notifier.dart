import 'package:flutter_riverpod/flutter_riverpod.dart';

class EventRegistrationNotifier extends StateNotifier<Set<String>> {
  EventRegistrationNotifier() : super({});

  void registerForEvent(String eventId) {
    state = {...state, eventId};
  }

  void unregisterFromEvent(String eventId) {
    state = state.where((id) => id != eventId).toSet();
  }

  bool isRegistered(String eventId) {
    return state.contains(eventId);
  }
}

final eventRegistrationProvider = StateNotifierProvider<EventRegistrationNotifier, Set<String>>((ref) {
  return EventRegistrationNotifier();
});
