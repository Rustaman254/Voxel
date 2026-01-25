import 'dart:async';
import '../../domain/services/voice_chat_service.dart';

class MockVoiceChatService implements VoiceChatService {
  final _stateController = StreamController<VoiceChatState>.broadcast();
  VoiceChatState _currentState = const VoiceChatState();

  @override
  Stream<VoiceChatState> get state => _stateController.stream;

  MockVoiceChatService() {
    // emit initial state
    _emit(_currentState);
  }

  void _emit(VoiceChatState state) {
    _currentState = state;
    _stateController.add(state);
  }

  @override
  Future<void> joinGroup(Set<String> userIds) async {
    _emit(VoiceChatState(
      status: VoiceChatStatus.connecting,
      connectedUserIds: _currentState.connectedUserIds,
    ));
    
    // Simulate connection time
    await Future.delayed(const Duration(milliseconds: 300));

    _emit(VoiceChatState(
      status: VoiceChatStatus.connected,
      connectedUserIds: userIds,
    ));
    print('VoiceChat: Joined group with ${userIds.length} users: $userIds');
  }

  @override
  Future<void> leaveGroup() async {
     _emit(VoiceChatState(
      status: VoiceChatStatus.disconnected,
      connectedUserIds: {},
    ));
    print('VoiceChat: Left group');
  }

  @override
  void sendAudioChunk(List<int> chunk) {
    // Mock implementation does nothing
  }
}
