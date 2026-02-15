import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/services/voice_chat_service.dart';
import '../repositories/socket_world_repository.dart';

class WebrtcVoiceService implements VoiceChatService {
  final SocketWorldRepository _socketRepository;
  final String _myUserId;

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Map<String, Timer> _peerHealthTimers = {};
  
  final _stateController = StreamController<VoiceChatState>.broadcast();
  VoiceChatState _currentState = const VoiceChatState();
  bool _isMuted = false;

  String? _currentChannelId;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

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
      
      _updateStatus(VoiceChatStatus.connected);
      _stateController.add(_currentState.copyWith(channelId: channelId));
      _reconnectAttempts = 0;
      
      debugPrint('✅ Successfully joined voice channel: $channelId');
    } catch (e) {
      debugPrint('❌ Failed to join voice channel: $e');
      _updateStatus(VoiceChatStatus.disconnected);
      _scheduleReconnect();
    }
  }

  @override
  Future<void> joinGroup(Set<String> userIds) async {
    // Proximity logic or manual group
    debugPrint('🎙️ Joining proximity group with ${userIds.length} users');
    
    try {
      await _initLocalStream();
      
      // Initiate calls to all users in the group
      for (final userId in userIds) {
        if (userId != _myUserId) {
          await initiateCall(userId);
        }
      }
      
      _updateStatus(VoiceChatStatus.connected);
    } catch (e) {
      debugPrint('❌ Failed to join proximity group: $e');
      _updateStatus(VoiceChatStatus.disconnected);
    }
  }

  @override
  Future<void> leaveChannel() async {
    debugPrint('🎙️ Leaving voice channel');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    // Cancel all health check timers
    for (var timer in _peerHealthTimers.values) {
      timer.cancel();
    }
    _peerHealthTimers.clear();
    
    // Close all peer connections
    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
    
    // Stop local stream
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localStream = null;
    
    _currentChannelId = null;
    _reconnectAttempts = 0;
    _updateStatus(VoiceChatStatus.disconnected);
    _stateController.add(const VoiceChatState());
    
    debugPrint('✅ Successfully left voice channel');
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
    debugPrint('🎤 Microphone ${muted ? "muted" : "unmuted"}');
  }

  @override
  void sendAudioChunk(List<int> chunk) {
    // Not used in WebRTC (WebRTC handles stream transmission)
  }

  Future<void> _initLocalStream() async {
    if (_localStream != null) return;

    // Request microphone permission
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      debugPrint('❌ Microphone permission denied');
      throw Exception('Microphone permission not granted');
    }

    // Enhanced audio constraints for better quality
    final Map<String, dynamic> constraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
        'sampleRate': 48000,
        'channelCount': 1,
        'googCpuOveruseDetection': true,
      },
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      await Helper.setSpeakerphoneOn(true);
      debugPrint('✅ Local audio stream initialized with enhanced quality');
    } catch (e) {
      debugPrint('❌ Failed to get local stream: $e');
      rethrow;
    }
  }

  Future<RTCPeerConnection> _createPeerConnection(String peerId) async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {
          'urls': 'turn:turn.codetalk.io:3478',
          'username': 'user',
          'credential': 'password'
        },
      ],
      'sdpSemantics': 'unified-plan',
      'iceTransportPolicy': 'relay',
    };

    final pc = await createPeerConnection(configuration);

    // Set Opus as the preferred codec
    final transceivers = await pc.getTransceivers();
    for (var t in transceivers) {
      if (t.sender.track?.kind == 'audio') {
        // Manually create RTCRtpCodecCapability for Opus
        final RTCRtpCodecCapability opusCodec = RTCRtpCodecCapability(
          mimeType: 'audio/opus',
          clockRate: 48000,
          channels: 2, // Opus typically uses 2 channels
        );
        
        await t.setCodecPreferences([opusCodec]);
        debugPrint('✅ Opus codec set as preferred for audio transceiver.');
      }
    }
    
    // Add local stream tracks
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    // ICE candidate handler
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _socketRepository.sendSignaling('webrtc_ice_candidate', peerId, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    // Connection state monitoring
    pc.onConnectionState = (state) {
      debugPrint('🔗 Connection state with $peerId: $state');
      
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _reconnectAttempts = 0;
        _startPeerHealthCheck(peerId);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
                 state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        debugPrint('⚠️ Connection with $peerId failed/disconnected, attempting reconnect');
        _handlePeerDisconnection(peerId);
      }
    };

    // ICE connection state monitoring
    pc.onIceConnectionState = (state) {
      debugPrint('🧊 ICE connection state with $peerId: $state');
    };

    // Remote stream handler
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        debugPrint('📡 Received remote stream from $peerId');
        _remoteStreams[peerId] = event.streams[0];
        _updateConnectedUsers();
      }
    };

    _peerConnections[peerId] = pc;
    return pc;
  }

  void _startPeerHealthCheck(String peerId) {
    _peerHealthTimers[peerId]?.cancel();
    
    // Check connection health every 10 seconds
    _peerHealthTimers[peerId] = Timer.periodic(const Duration(seconds: 10), (timer) {
      final pc = _peerConnections[peerId];
      if (pc == null) {
        timer.cancel();
        return;
      }
      
      pc.getStats().then((stats) {
        // Monitor connection quality
        // This is a placeholder for more sophisticated health checks
        debugPrint('📊 Connection stats for $peerId available');
      }).catchError((error) {
        debugPrint('⚠️ Failed to get stats for $peerId: $error');
      });
    });
  }

  void _handlePeerDisconnection(String peerId) async {
    _peerHealthTimers[peerId]?.cancel();
    _peerHealthTimers.remove(peerId);
    
    final pc = _peerConnections[peerId];
    if (pc != null) {
      await pc.close();
      _peerConnections.remove(peerId);
      _remoteStreams.remove(peerId);
      _updateConnectedUsers();
    }
    
    // Attempt to reconnect if we're still in a channel
    if (_currentChannelId != null && _reconnectAttempts < 3) {
      _reconnectAttempts++;
      debugPrint('🔄 Attempting to reconnect to $peerId (attempt $_reconnectAttempts/3)');
      
      await Future.delayed(Duration(seconds: _reconnectAttempts * 2));
      
      if (_currentChannelId != null) {
        await initiateCall(peerId);
      }
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= 5) {
      debugPrint('❌ Max reconnection attempts reached');
      return;
    }
    
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    
    debugPrint('🔄 Scheduling reconnect in ${delay.inSeconds}s (attempt ${_reconnectAttempts + 1}/5)');
    
    _reconnectTimer = Timer(delay, () {
      if (_currentChannelId != null) {
        _reconnectAttempts++;
        joinChannel(_currentChannelId!);
      }
    });
  }

  Future<void> _handleOffer(String senderId, dynamic data) async {
    try {
      debugPrint('📨 Received WebRTC Offer from $senderId');
      
      // Close existing connection if any
      final existingPc = _peerConnections[senderId];
      if (existingPc != null) {
        await existingPc.close();
      }
      
      final pc = await _createPeerConnection(senderId);
      
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      _socketRepository.sendSignaling('webrtc_answer', senderId, {
        'sdp': answer.sdp,
        'type': answer.type,
      });
      
      debugPrint('✅ Sent WebRTC Answer to $senderId');
    } catch (e) {
      debugPrint('❌ Error handling offer from $senderId: $e');
    }
  }

  Future<void> _handleAnswer(String senderId, dynamic data) async {
    try {
      debugPrint('📨 Received WebRTC Answer from $senderId');
      final pc = _peerConnections[senderId];
      if (pc != null) {
        await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
        debugPrint('✅ Set remote description for $senderId');
      } else {
        debugPrint('⚠️ No peer connection found for $senderId');
      }
    } catch (e) {
      debugPrint('❌ Error handling answer from $senderId: $e');
    }
  }

  Future<void> _handleIceCandidate(String senderId, dynamic data) async {
    try {
      final pc = _peerConnections[senderId];
      if (pc != null) {
        await pc.addCandidate(RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        ));
        debugPrint('✅ Added ICE candidate from $senderId');
      } else {
        debugPrint('⚠️ No peer connection found for ICE candidate from $senderId');
      }
    } catch (e) {
      debugPrint('❌ Error handling ICE candidate from $senderId: $e');
    }
  }

  @override
  Future<void> initiateCall(String peerId) async {
    if (_peerConnections.containsKey(peerId)) {
      debugPrint('⚠️ Already have connection with $peerId');
      return;
    }
    
    // Lexicographical rule to avoid race conditions
    if (_myUserId.compareTo(peerId) > 0) {
      debugPrint('⏳ Waiting for $peerId to initiate call (lexicographical rule)');
      return;
    }

    try {
      debugPrint('📞 Initiating WebRTC Call to $peerId');
      final pc = await _createPeerConnection(peerId);
      
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      _socketRepository.sendSignaling('webrtc_offer', peerId, {
        'sdp': offer.sdp,
        'type': offer.type,
      });
      
      debugPrint('✅ Sent WebRTC Offer to $peerId');
    } catch (e) {
      debugPrint('❌ Failed to initiate call to $peerId: $e');
      _handlePeerDisconnection(peerId);
    }
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
    debugPrint('👥 Connected users: ${_remoteStreams.length}');
  }
  
  void dispose() {
    _reconnectTimer?.cancel();
    for (var timer in _peerHealthTimers.values) {
      timer.cancel();
    }
    _peerHealthTimers.clear();
    leaveChannel();
    _stateController.close();
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
