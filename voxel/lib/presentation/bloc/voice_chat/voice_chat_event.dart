part of 'voice_chat_bloc.dart';

abstract class VoiceChatEvent extends Equatable {
  const VoiceChatEvent();

  @override
  List<Object?> get props => [];
}

class JoinVoiceChannel extends VoiceChatEvent {
  final String channelId;

  const JoinVoiceChannel(this.channelId);

  @override
  List<Object?> get props => [channelId];
}

class JoinVoiceGroup extends VoiceChatEvent {
  final Set<String> userIds;

  const JoinVoiceGroup(this.userIds);

  @override
  List<Object?> get props => [userIds];
}

class LeaveVoiceChannel extends VoiceChatEvent {
  const LeaveVoiceChannel();
}

class ToggleMute extends VoiceChatEvent {
  final bool muted;

  const ToggleMute(this.muted);

  @override
  List<Object?> get props => [muted];
}

class InitiateVoiceCall extends VoiceChatEvent {
  final String peerId;

  const InitiateVoiceCall(this.peerId);

  @override
  List<Object?> get props => [peerId];
}

class VoiceStateUpdated extends VoiceChatEvent {
  final domain.VoiceChatState voiceState;

  const VoiceStateUpdated(this.voiceState);

  @override
  List<Object?> get props => [voiceState];
}
