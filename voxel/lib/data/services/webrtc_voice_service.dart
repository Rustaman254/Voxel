import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../domain/services/voice_chat_service.dart';
import '../../domain/repositories/world_repository.dart';

class WebRtcVoiceService implements VoiceChatService {
  final WorldRepository _repository;
  final String _currentUserId;
  
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {}; // Renderers handle audio too
  
  final StreamController<VoiceChatState> _stateController = StreamController<VoiceChatState>.broadcast();
  VoiceChatState _currentState = const VoiceChatState();
  
  bool _isDisposed = false;

  WebRtcVoiceService(this._repository, this._currentUserId) {
    _initLocalStream();
    _repository.subscribeSignaling().listen(_handleSignaling);
  }

  Future<void> _initLocalStream() async {
    try {
      // Request Microphone Permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint('❌ Microphone permission denied');
        _emit(_currentState.copyWith(status: VoiceChatStatus.disconnected));
        return;
      }

      final Map<String, dynamic> constraints = {
        'audio': {
           'echoCancellation': true,
           'noiseSuppression': true,
           'autoGainControl': true,
        },
        'video': false,
      };
      
      debugPrint('🎙️ Requesting local media...');
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      // Ensure audio is enabled
      _localStream!.getAudioTracks().forEach((track) {
        track.enabled = true;
        debugPrint('✅ Audio track enabled: ${track.id}');
      });

      // Ensure audio is routed to speaker by default for voice chat feel
      if (!kIsWeb) {
        await Helper.setSpeakerphoneOn(true);
        debugPrint('🔊 Speakerphone enabled');
      }
      
      debugPrint('✅ Local WebRTC audio stream initialized');
      _emit(_currentState.copyWith(status: VoiceChatStatus.connected));
      
      _startVoiceActivityMonitor();
    } catch (e) {
      debugPrint('❌ Failed to get local media: $e');
      _emit(_currentState.copyWith(status: VoiceChatStatus.disconnected));
    }
  }

  Timer? _statsTimer;
  void _startVoiceActivityMonitor() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
       if (_isDisposed) return;
       
       // For "ME" (Local)
       // Peer connection stats for local are tricky, so we'll just assume true if active 
       // or look for a way to monitor local track.
       // For now, let's look at remote connections to see if they are "receiving" levels.
       
       bool anyoneTalking = false;
       for (final pc in _peerConnections.values) {
         try {
           final stats = await pc.getStats();
           for (final report in stats) {
             if (report.type == 'media-source' && report.values['kind'] == 'audio') {
                final level = report.values['audioLevel'] ?? 0.0;
                if (level > 0.01) anyoneTalking = true;
             }
           }
         } catch (_) {}
       }
       
       if (anyoneTalking != _currentState.isTalking) {
         _emit(_currentState.copyWith(isTalking: anyoneTalking));
       }
    });
  }

  void _handleSignaling(Map<String, dynamic> signaling) {
    final targetId = signaling['targetId'];
    final senderId = signaling['senderId'];
    final type = signaling['type'];
    final data = signaling['data'];

    // Only process if it's meant for me
    if (targetId != _currentUserId) return;

    debugPrint('📨 Received WebRTC signaling: $type from $senderId');

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
  }

  Future<void> _handleOffer(String senderId, dynamic data) async {
    final pc = await _getOrCreatePeerConnection(senderId);
    await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
    
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    
    _repository.sendSignaling('webrtc_answer', senderId, {
      'sdp': answer.sdp,
      'type': answer.type,
    });
  }

  Future<void> _handleAnswer(String senderId, dynamic data) async {
    final pc = _peerConnections[senderId];
    if (pc != null) {
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
    }
  }

  Future<void> _handleIceCandidate(String senderId, dynamic data) async {
    final pc = _peerConnections[senderId];
    if (pc != null) {
      await pc.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
    }
  }

  Future<RTCPeerConnection> _getOrCreatePeerConnection(String peerId) async {
    if (_peerConnections.containsKey(peerId)) {
      return _peerConnections[peerId]!;
    }

    final Map<String, dynamic> config = {
      'iceServers': [
        {'url': 'stun:stun.l.google.com:19302'},
        {'url': 'stun:stun1.l.google.com:19302'},
      ]
    };

    final pc = await createPeerConnection(config);
    _peerConnections[peerId] = pc;

    // Add local stream
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      _repository.sendSignaling('webrtc_ice_candidate', peerId, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _setupRemoteAudio(peerId, event.streams[0]);
      }
    };

    pc.onConnectionState = (state) {
      debugPrint('Connection state for $peerId: $state');
    };

    return pc;
  }

  Future<void> _setupRemoteAudio(String peerId, MediaStream stream) async {
    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    renderer.srcObject = stream;
    _remoteRenderers[peerId] = renderer;
    debugPrint('🔊 Remote audio attached for $peerId');
  }

  @override
  Stream<VoiceChatState> get state => _stateController.stream;

  @override
  Future<void> joinGroup(Set<String> userIds) async {
    // For each "new" user in proximity that isn't connected, initiate connection
    for (final peerId in userIds) {
      if (peerId == _currentUserId) continue;
      if (!_peerConnections.containsKey(peerId)) {
        debugPrint('🤝 Initiating WebRTC offer to $peerId');
        final pc = await _getOrCreatePeerConnection(peerId);
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        
        _repository.sendSignaling('webrtc_offer', peerId, {
          'sdp': offer.sdp,
          'type': offer.type,
        });
      }
    }
    
    // Close connections to users no longer in the set
    _cleanRedundantConnections(userIds);
    
    _emit(_currentState.copyWith(connectedUserIds: userIds));
  }

  void _cleanRedundantConnections(Set<String> currentNearbyIds) {
    final keysToRemove = <String>[];
    _peerConnections.forEach((peerId, pc) {
      if (!currentNearbyIds.contains(peerId)) {
        keysToRemove.add(peerId);
      }
    });

    for (final key in keysToRemove) {
      debugPrint('👋 Closing WebRTC connection to $key');
      _peerConnections[key]?.close();
      _peerConnections.remove(key);
      _remoteRenderers[key]?.dispose();
      _remoteRenderers.remove(key);
    }
  }

  @override
  Future<void> leaveGroup() async {
    _cleanRedundantConnections({});
    _emit(_currentState.copyWith(connectedUserIds: {}));
  }

  @override
  void sendAudioChunk(List<int> chunk) {
    // WebRTC handles audio streaming directly via tracks, 
    // so manual chunks are not needed here.
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    
    await leaveGroup();
    await _localStream?.dispose();
    await _stateController.close();
  }

  void _emit(VoiceChatState state) {
    if (_isDisposed) return;
    _currentState = state;
    _stateController.add(state);
  }
}

extension on VoiceChatState {
  VoiceChatState copyWith({VoiceChatStatus? status, Set<String>? connectedUserIds, bool? isTalking}) {
    return VoiceChatState(
      status: status ?? this.status,
      connectedUserIds: connectedUserIds ?? this.connectedUserIds,
      isTalking: isTalking ?? this.isTalking,
    );
  }
}
