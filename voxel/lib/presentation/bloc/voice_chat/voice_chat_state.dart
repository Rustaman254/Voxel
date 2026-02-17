part of 'voice_chat_bloc.dart';

abstract class VoiceChatBlocState extends Equatable {
  const VoiceChatBlocState();

  @override
  List<Object?> get props => [];
}

class VoiceChatInitial extends VoiceChatBlocState {
  const VoiceChatInitial();
}

class VoiceChatConnecting extends VoiceChatBlocState {
  final String? channelId;

  const VoiceChatConnecting({this.channelId});

  @override
  List<Object?> get props => [channelId];
}

class VoiceChatConnected extends VoiceChatBlocState {
  final String? channelId;
  final Set<String> connectedUserIds;
  final bool isMuted;
  final bool isTalking;

  const VoiceChatConnected({
    this.channelId,
    this.connectedUserIds = const {},
    this.isMuted = false,
    this.isTalking = false,
  });

  @override
  List<Object?> get props => [channelId, connectedUserIds, isMuted, isTalking];

  VoiceChatConnected copyWith({
    String? channelId,
    Set<String>? connectedUserIds,
    bool? isMuted,
    bool? isTalking,
  }) {
    return VoiceChatConnected(
      channelId: channelId ?? this.channelId,
      connectedUserIds: connectedUserIds ?? this.connectedUserIds,
      isMuted: isMuted ?? this.isMuted,
      isTalking: isTalking ?? this.isTalking,
    );
  }
}

class VoiceChatDisconnected extends VoiceChatBlocState {
  const VoiceChatDisconnected();
}

class VoiceChatError extends VoiceChatBlocState {
  final String message;
  final String? channelId;

  const VoiceChatError(this.message, {this.channelId});

  @override
  List<Object?> get props => [message, channelId];
}
