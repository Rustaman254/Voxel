abstract class VoiceChatService {
  /// Connect to audio channel with the given set of users
  Future<void> joinGroup(Set<String> userIds);

  /// Leave current audio channel
  Future<void> leaveGroup();

  /// Stream of current voice state (e.g. connected users, connection status)
  Stream<VoiceChatState> get state;

  /// Mute or unmute the microphone
  void setMuted(bool muted);

  /// Send audio chunk
  void sendAudioChunk(List<int> chunk);
}

enum VoiceChatStatus { disconnected, connecting, connected }

class VoiceChatState {
  final VoiceChatStatus status;
  final Set<String> connectedUserIds;
  final bool isTalking;

  const VoiceChatState({
    this.status = VoiceChatStatus.disconnected,
    this.connectedUserIds = const {},
    this.isTalking = false,
  });
}
