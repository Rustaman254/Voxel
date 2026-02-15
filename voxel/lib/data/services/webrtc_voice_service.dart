import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../domain/services/voice_chat_service.dart';
import '../repositories/socket_world_repository.dart';

class WebrtcVoiceService implements VoiceChatService {
  final SocketWorldRepository _socketRepository;
  final String _myUserId;

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  
  final _stateController = StreamController<VoiceChatState>.broadcast();
  VoiceChatState _currentState = const VoiceChatState();

  String? _currentChannelId;
  bool _isMuted = false;

  WebrtcVoiceService(this._socketRepository, this._myUserId) {
    _initSignaling();
  }

  void _initSignaling() {
    _socketRepository.subscribeSignaling().listen((message) {
      final type = message['type'];
      final senderId = message['senderId'];
      final data = message['data'];

      if (senderId == _myUserId) return;

      switch (type) {
        case 'webrtc_offer':
          _handleOffer(senderId, data);
          break;
        case 'webrtc_answer':
          _handleAnswer(senderId, data);
          break;
        case 'webrtc_ice_candidate':
          _handleIceCandidate(senderId, data);
          break;
      }
    });
  }

  @override
  Future<void> joinChannel(String channelId) async {
    if (_currentChannelId == channelId) return;
    
    debugPrint('🎙️ Joining voice channel: $channelId');
    _currentChannelId = channelId;
    _updateStatus(VoiceChatStatus.connecting);

    try {
      await _initLocalStream();
      
      // In a Mesh network, we don't necessarily "join" a channel on a server.
      // We just start signaling peers in that same logical group.
      // The server already isolates signaling via SessionID/ChannelID.
      
      _updateStatus(VoiceChatStatus.connected);
      _stateController.add(_currentState.copyWith(channelId: channelId));
    } catch (e) {
      debugPrint('❌ Failed to join voice channel: $e');
      _updateStatus(VoiceChatStatus.disconnected);
    }
  }

  @override
  Future<void> joinGroup(Set<String> userIds) async {
    // Proximity logic or manual group
    // For now, we focus on Room channels.
  }

  @override
  Future<void> leaveChannel() async {
    debugPrint('🎙️ Leaving voice channel');
    for (var pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
    
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    
    _currentChannelId = null;
    _updateStatus(VoiceChatStatus.disconnected);
    _stateController.add(const VoiceChatState());
  }

  @override
  Stream<VoiceChatState> get state => _stateController.stream;

  @override
  void setMuted(bool muted) {
    _isMuted = muted;
    _localStream?.getAudioTracks().forEach((track) {
      track.enabled = !muted;
    });
    _stateController.add(_currentState.copyWith(isTalking: !muted));
  }

  @override
  void sendAudioChunk(List<int> chunk) {
    // Not used in WebRTC (WebRTC handles stream transmission)
  }

  Future<void> _initLocalStream() async {
    if (_localStream != null) return;

    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    };

    final pc = await createPeerConnection(configuration);
    
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      _socketRepository.sendSignaling('webrtc_ice_candidate', peerId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[peerId] = event.streams[0];
        _updateConnectedUsers();
      }
    };

    _peerConnections[peerId] = pc;
    return pc;
  }

  Future<void> _handleOffer(String senderId, dynamic data) async {
    debugPrint('📨 Received WebRTC Offer from $senderId');
    final pc = await _createPeerConnection(senderId);
    
    await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _socketRepository.sendSignaling('webrtc_answer', senderId, {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  Future<void> _handleAnswer(String senderId, dynamic data) async {
    debugPrint('📨 Received WebRTC Answer from $senderId');
    final pc = _peerConnections[senderId];
    if (pc != null) {
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
    }
  }

  Future<void> _handleIceCandidate(String senderId, dynamic data) async {
    final pc = _peerConnections[senderId];
    if (pc != null) {
      await pc.addCandidate(RTCIceCandidate(
        data['candidate'],
        data['sdpMid'],
        data['sdpMLineIndex'],
      ));
    }
  }

  // Called by RoomController when a new peer is discovered
  Future<void> initiateCall(String peerId) async {
    if (_peerConnections.containsKey(peerId)) return;
    
    // Lexicographical rule to avoid race conditions: 
    // Only the user with the "smaller" ID initiates.
    if (_myUserId.compareTo(peerId) > 0) {
      debugPrint('⏳ Waiting for $peerId to initiate call (lexicographical rule)');
      return;
    }

    debugPrint('📞 Initiating WebRTC Call to $peerId');
    final pc = await _createPeerConnection(peerId);
    
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);

    _socketRepository.sendSignaling('webrtc_offer', peerId, {
      'sdp': offer.sdp,
      'type': offer.type,
    });
  }

  void _updateStatus(VoiceChatStatus status) {
    _currentState = _currentState.copyWith(status: status);
    _stateController.add(_currentState);
  }

  void _updateConnectedUsers() {
    _currentState = _currentState.copyWith(
      connectedUserIds: _remoteStreams.keys.toSet(),
    );
    _stateController.add(_currentState);
  }
}

extension on VoiceChatState {
  VoiceChatState copyWith({
    VoiceChatStatus? status,
    Set<String>? connectedUserIds,
    bool? isTalking,
    String? channelId,
  }) {
    return VoiceChatState(
      status: status ?? this.status,
      connectedUserIds: connectedUserIds ?? this.connectedUserIds,
      isTalking: isTalking ?? this.isTalking,
      channelId: channelId ?? this.channelId,
    );
  }
}
