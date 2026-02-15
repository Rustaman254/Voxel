abstract class VoiceChatService {
  /// Connect to a specific audio channel (e.g. a room ID)
  Future<void> joinChannel(String channelId);

  /// Connect to audio channel with the given set of users (Proximity Chat)
  Future<void> joinGroup(Set<String> userIds);

  /// Leave current audio channel
  Future<void> leaveChannel();

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
  final String? channelId; // Null for Proximity, RoomID for Rooms

  const VoiceChatState({
    this.status = VoiceChatStatus.disconnected,
    this.connectedUserIds = const {},
    this.isTalking = false,
    this.channelId,
  });
}
