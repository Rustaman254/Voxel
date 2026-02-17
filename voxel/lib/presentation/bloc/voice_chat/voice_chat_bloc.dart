import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/services/voice_chat_service.dart' as domain;

part 'voice_chat_event.dart';
part 'voice_chat_state.dart';

class VoiceChatBloc extends Bloc<VoiceChatEvent, VoiceChatBlocState> {
  final domain.VoiceChatService _voiceService;
  StreamSubscription? _voiceStateSubscription;

  VoiceChatBloc(this._voiceService) : super(const VoiceChatInitial()) {
    // Listen to voice service state changes
    _voiceStateSubscription = _voiceService.state.listen((voiceState) {
      add(VoiceStateUpdated(voiceState));
    });

    on<JoinVoiceChannel>(_onJoinChannel);
    on<JoinVoiceGroup>(_onJoinGroup);
    on<LeaveVoiceChannel>(_onLeaveChannel);
    on<ToggleMute>(_onToggleMute);
    on<InitiateVoiceCall>(_onInitiateCall);
    on<VoiceStateUpdated>(_onVoiceStateUpdated);
  }

  Future<void> _onJoinChannel(
    JoinVoiceChannel event,
    Emitter<VoiceChatBlocState> emit,
  ) async {
    try {
      emit(VoiceChatConnecting(channelId: event.channelId));
      await _voiceService.joinChannel(event.channelId);
      // State will be updated via VoiceStateUpdated event from stream
    } catch (e) {
      debugPrint('❌ Error joining voice channel: $e');
      emit(VoiceChatError(
        'Failed to join voice channel: ${e.toString()}',
        channelId: event.channelId,
      ));
    }
  }

  Future<void> _onJoinGroup(
    JoinVoiceGroup event,
    Emitter<VoiceChatBlocState> emit,
  ) async {
    try {
      emit(const VoiceChatConnecting());
      await _voiceService.joinGroup(event.userIds);
      // State will be updated via VoiceStateUpdated event from stream
    } catch (e) {
      debugPrint('❌ Error joining voice group: $e');
      emit(VoiceChatError('Failed to join voice group: ${e.toString()}'));
    }
  }

  Future<void> _onLeaveChannel(
    LeaveVoiceChannel event,
    Emitter<VoiceChatBlocState> emit,
  ) async {
    try {
      await _voiceService.leaveChannel();
      emit(const VoiceChatDisconnected());
    } catch (e) {
      debugPrint('❌ Error leaving voice channel: $e');
      emit(VoiceChatError('Failed to leave voice channel: ${e.toString()}'));
    }
  }

  void _onToggleMute(
    ToggleMute event,
    Emitter<VoiceChatBlocState> emit,
  ) {
    try {
      _voiceService.setMuted(event.muted);
      
      // Update current state if connected
      if (state is VoiceChatConnected) {
        final currentState = state as VoiceChatConnected;
        emit(currentState.copyWith(
          isMuted: event.muted,
          isTalking: !event.muted,
        ));
      }
    } catch (e) {
      debugPrint('❌ Error toggling mute: $e');
      emit(VoiceChatError('Failed to toggle mute: ${e.toString()}'));
    }
  }

  Future<void> _onInitiateCall(
    InitiateVoiceCall event,
    Emitter<VoiceChatBlocState> emit,
  ) async {
    try {
      await _voiceService.initiateCall(event.peerId);
    } catch (e) {
      debugPrint('❌ Error initiating call: $e');
      emit(VoiceChatError('Failed to initiate call: ${e.toString()}'));
    }
  }

  void _onVoiceStateUpdated(
    VoiceStateUpdated event,
    Emitter<VoiceChatBlocState> emit,
  ) {
    final voiceState = event.voiceState;
    
    switch (voiceState.status) {
      case domain.VoiceChatStatus.connecting:
        emit(VoiceChatConnecting(channelId: voiceState.channelId));
        break;
      case domain.VoiceChatStatus.connected:
        emit(VoiceChatConnected(
          channelId: voiceState.channelId,
          connectedUserIds: voiceState.connectedUserIds,
          isTalking: voiceState.isTalking,
          isMuted: !voiceState.isTalking,
        ));
        break;
      case domain.VoiceChatStatus.disconnected:
        emit(const VoiceChatDisconnected());
        break;
    }
  }

  @override
  Future<void> close() {
    _voiceStateSubscription?.cancel();
    return super.close();
  }
}
