import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'auth_notifier.dart';

class EventRegistrationNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  
  EventRegistrationNotifier(this._ref) : super({}) {
    _fetchRegisteredEvents();
  }

  static String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) {
      return 'http://192.168.1.4:8080'; 
    }
    return 'http://192.168.1.4:8080';
  }

  Future<void> _fetchRegisteredEvents() async {
    final token = _ref.read(authProvider).user?.authToken;
    if (token == null) return;

    try {
      final url = Uri.parse('$_baseUrl/api/events/registered');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // Assuming the API returns a list of events, we extract IDs
        // Or if it returns IDs directly. 
        // Based on typical implementation, it might differ.
        // Let's assume it returns list of Event objects, so we map to IDs.
        // If it returns list of strings, we just cast.
        // Safe check:
        if (data.isNotEmpty) {
           if (data[0] is String) {
             state = Set<String>.from(data);
           } else {
             state = data.map((e) => e['id'] as String).toSet();
           }
        }
      }
    } catch (e) {
      debugPrint('Error fetching registered events: $e');
    }
  }

  Future<void> registerForEvent(String eventId) async {
    // Optimistic update
    state = {...state, eventId};
    
    final token = _ref.read(authProvider).user?.authToken;
    if (token == null) {
       // Revert if no token
       state = state.where((id) => id != eventId).toSet();
       return;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/events/$eventId/register');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        // Revert on failure
        state = state.where((id) => id != eventId).toSet();
        debugPrint('Failed to register: ${response.body}');
      }
    } catch (e) {
      // Revert on error
      state = state.where((id) => id != eventId).toSet();
      debugPrint('Error registering for event: $e');
    }
  }

  Future<void> unregisterFromEvent(String eventId) async {
    // Optimistic update
    state = state.where((id) => id != eventId).toSet();

    final token = _ref.read(authProvider).user?.authToken;
    if (token == null) {
       state = {...state, eventId};
       return;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/events/$eventId/unregister');
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        state = {...state, eventId};
        debugPrint('Failed to unregister: ${response.body}');
      }
    } catch (e) {
      state = {...state, eventId};
      debugPrint('Error unregistering from event: $e');
    }
  }

  bool isRegistered(String eventId) {
    return state.contains(eventId);
  }
}

final eventRegistrationProvider = StateNotifierProvider<EventRegistrationNotifier, Set<String>>((ref) {
  return EventRegistrationNotifier(ref);
});
