// voxel/lib/core/webrtc_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart'; // For logging

final webrtcServiceProvider = Provider((ref) => WebRTCService(ref));

class WebRTCService {
  final Ref _ref;
  final _log = Logger('WebRTCService');

  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  final Uuid _uuid = Uuid();

  // WebSocket channel to the server (assuming it's managed externally)
  WebSocketChannel? _channel;
  String? _currentSessionId;
  String? _currentUserId;

  WebRTCService(this._ref);

  void setWebSocketChannel(WebSocketChannel channel, String userId, String sessionId) {
    _channel = channel;
    _currentUserId = userId;
    _currentSessionId = sessionId;
    _channel?.stream.listen(_handleWebSocketMessage);
    _log.info('WebSocket channel set for User: $userId, Session: $sessionId');
  }

  Future<void> initLocalStream() async {
    _log.info('Initializing local stream...');
    // Request microphone permission
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _log.severe('Microphone permission not granted');
      throw Exception('Microphone permission not granted');
    }

    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _log.info('Local stream obtained successfully.');
    } catch (e) {
      _log.severe('Error getting local stream: $e');
    }
  }

  MediaStream? get localStream => _localStream;
  Map<String, MediaStream> get remoteStreams => _remoteStreams;

  Future<void> connectToPeer(String peerId) async {
    if (_peerConnections.containsKey(peerId)) {
      _log.warning('Already connected to peer: $peerId');
      return;
    }

    _log.info('Connecting to peer: $peerId');
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    final RTCPeerConnection peerConnection = await createPeerConnection(configuration);
    _peerConnections[peerId] = peerConnection;

    // Add local stream to peer connection
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        peerConnection.addTrack(track, _localStream!);
      });
      _log.info('Local stream added to peer connection for $peerId');
    }

    peerConnection.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate == null) return;
      _log.info('Sending ICE candidate to $peerId: ${candidate.candidate}');
      _sendWebSocketMessage('webrtc_ice_candidate', {
        'to': peerId,
        'candidate': candidate.toMap(),
      });
    };

    peerConnection.onIceGatheringState = (RTCIceGatheringState state) {
      _log.info('ICE Gathering State for $peerId: $state');
    };

    peerConnection.onAddStream = (MediaStream stream) {
      _log.info('Remote stream added from $peerId: ${stream.id}');
      _remoteStreams[peerId] = stream;
      // You might need to trigger a UI update here
    };

    // Create an offer to send to the peer
    if (peerId != _currentUserId) { // Only create offer if not connecting to self
      RTCSessionDescription offer = await peerConnection.createOffer();
      await peerConnection.setLocalDescription(offer);
      _log.info('Sending WebRTC offer to $peerId');
      _sendWebSocketMessage('webrtc_offer', {
        'to': peerId,
        'sdp': offer.toMap(),
      });
    }
  }

  Future<void> disconnectFromPeer(String peerId) async {
    _log.info('Disconnecting from peer: $peerId');
    await _peerConnections[peerId]?.close();
    _peerConnections.remove(peerId);
    _remoteStreams.remove(peerId);
    // Trigger UI update if necessary
  }

  void _sendWebSocketMessage(String type, Map<String, dynamic> payload) {
    if (_channel == null || _currentUserId == null || _currentSessionId == null) {
      _log.warning('WebSocket channel or user/session ID not set. Cannot send message.');
      return;
    }
    final message = {
      'type': type,
      'payload': {
        'from': _currentUserId,
        'sessionId': _currentSessionId,
        ...payload,
      },
    };
    _channel?.sink.add(jsonEncode(message));
    _log.fine('Sent WebSocket message: $type to ${_currentSessionId}');
  }

  void _handleWebSocketMessage(dynamic message) async {
    _log.fine('Received WebSocket message: $message');
    final Map<String, dynamic> decodedMessage = jsonDecode(message);
    final String type = decodedMessage['type'];
    final Map<String, dynamic> payload = decodedMessage['payload'];
    final String fromPeerId = payload['from'];
    final String? toPeerId = payload['to']; // Optional, for directed messages

    // Ignore messages not intended for us, or from ourselves
    if (toPeerId != null && toPeerId != _currentUserId) {
      return;
    }
    if (fromPeerId == _currentUserId) {
      return;
    }

    // Ensure we have a peer connection with the sender
    if (!_peerConnections.containsKey(fromPeerId)) {
      await connectToPeer(fromPeerId); // Establish connection if not already
    }
    final RTCPeerConnection peerConnection = _peerConnections[fromPeerId]!;

    switch (type) {
      case 'webrtc_offer':
        _log.info('Received WebRTC offer from $fromPeerId');
        final RTCSessionDescription offer = RTCSessionDescription(
          payload['sdp']['sdp'],
          payload['sdp']['type'],
        );
        await peerConnection.setRemoteDescription(offer);
        RTCSessionDescription answer = await peerConnection.createAnswer();
        await peerConnection.setLocalDescription(answer);
        _sendWebSocketMessage('webrtc_answer', {
          'to': fromPeerId,
          'sdp': answer.toMap(),
        });
        break;
      case 'webrtc_answer':
        _log.info('Received WebRTC answer from $fromPeerId');
        final RTCSessionDescription answer = RTCSessionDescription(
          payload['sdp']['sdp'],
          payload['sdp']['type'],
        );
        await peerConnection.setRemoteDescription(answer);
        break;
      case 'webrtc_ice_candidate':
        _log.info('Received ICE candidate from $fromPeerId');
        final RTCIceCandidate candidate = RTCIceCandidate(
          payload['candidate']['candidate'],
          payload['candidate']['sdpMid'],
          payload['candidate']['sdpMLineIndex'],
        );
        await peerConnection.addCandidate(candidate);
        break;
      default:
        _log.warning('Unhandled WebSocket message type: $type');
    }
  }

  void dispose() {
    _log.info('Disposing WebRTCService');
    _localStream?.getTracks().forEach((track) => track.dispose());
    _localStream?.dispose();
    _peerConnections.forEach((key, pc) => pc.close());
    _peerConnections.clear();
    _remoteStreams.forEach((key, stream) => stream.dispose());
    _remoteStreams.clear();
    _channel?.sink.close();
  }
}
