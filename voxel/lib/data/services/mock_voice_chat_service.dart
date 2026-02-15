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
  Future<void> joinChannel(String channelId) async {
    _emit(VoiceChatState(
      status: VoiceChatStatus.connecting,
      connectedUserIds: {},
      channelId: channelId,
    ));
    
    // Simulate connection time
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate some users already in the room
    final mockUsers = {'user_1', 'user_2'};

    _emit(VoiceChatState(
      status: VoiceChatStatus.connected,
      connectedUserIds: mockUsers,
      channelId: channelId,
    ));
    print('VoiceChat: Joined channel $channelId with Mock Users: $mockUsers');
  }

  @override
  Future<void> joinGroup(Set<String> userIds) async {
    _emit(VoiceChatState(
      status: VoiceChatStatus.connecting,
      connectedUserIds: _currentState.connectedUserIds,
      channelId: _currentState.channelId,
    ));
    
    // Simulate connection time
    await Future.delayed(const Duration(milliseconds: 300));

    _emit(VoiceChatState(
      status: VoiceChatStatus.connected,
      connectedUserIds: userIds,
      channelId: null, // Proximity has no channel ID
    ));
    print('VoiceChat: Joined proximity group with ${userIds.length} users');
  }

  @override
  Future<void> leaveChannel() async {
     _emit(const VoiceChatState(
      status: VoiceChatStatus.disconnected,
    ));
    print('VoiceChat: Left channel/group');
  }

  @override
  void sendAudioChunk(List<int> chunk) {
    // Mock implementation does nothing
  }

  @override
  void setMuted(bool muted) {
    // Mock implementation does nothing
    print('VoiceChat: Muted = $muted');
  }
}
