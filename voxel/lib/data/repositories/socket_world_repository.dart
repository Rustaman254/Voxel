import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import '../../domain/entities/avatar_position.dart';
import '../../domain/repositories/world_repository.dart';

class SocketWorldRepository implements WorldRepository {
  WebSocketChannel? _channel;
  final _positionController = StreamController<List<AvatarPosition>>.broadcast();
  
  // Local cache of peers
  final Map<String, AvatarPosition> _peers = {};
  
  // Determine URL based on platform/build config
  // Current Machine IP: 192.168.1.133
  static const String _defaultWsUrl = 'wss://voxel-nxjg.onrender.com/ws';
  final String _wsUrl = const String.fromEnvironment('WS_URL', defaultValue: _defaultWsUrl);

  final _statusController = StreamController<bool>.broadcast();
  final _audioController = StreamController<Map<String, dynamic>>.broadcast();
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  final _eventsListController = StreamController<List<dynamic>>.broadcast();
  final _sessionController = StreamController<Map<String, dynamic>>.broadcast();
  final _signalingController = StreamController<Map<String, dynamic>>.broadcast();
  
  bool _isConnected = false;
  String? _lastUserId;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _isConnecting = false;
  
  // Snapchat-like smooth movement settings
  static const Duration _syncInterval = Duration(milliseconds: 100);
  static const Duration _glideDuration = Duration(milliseconds: 800);
  
  @override
  Future<void> connect(String userId) async {
    // CRITICAL: Remove fragment and query params from userId before anything else
    userId = userId.split('#')[0].split('?')[0].trim();
    
    if (_isConnecting || (_isConnected && _lastUserId == userId)) return;
    
    _isConnecting = true;
    _lastUserId = userId;
    
    if (_wsUrl.isEmpty) {
      debugPrint('❌ WS URL is empty!');
      _isConnecting = false;
      return;
    }

    try {
      _reconnectTimer?.cancel();
      
      // Clean the base URL
      String base = _wsUrl.trim();
      
      // Force WSS
      base = base.replaceFirst('http://', 'wss://').replaceFirst('https://', 'wss://').replaceFirst('ws://', 'wss://');
      if (!base.startsWith('wss://')) base = 'wss://$base';
      
      // Remove trailing slash from base
      if (base.endsWith('/')) base = base.substring(0, base.length - 1);
      
      // Clean userId - URL encode it properly
      final cleanUserId = Uri.encodeComponent(userId);
      
      // Construct final URL - simpler approach
      final finalUrl = '$base?userId=$cleanUserId';
      
      debugPrint('🔗 Connecting to: $finalUrl');

      if (!kIsWeb) {
        // Use IOWebSocketChannel.connect for simpler, more reliable connection
        _channel = IOWebSocketChannel.connect(
          Uri.parse(finalUrl),
          headers: {
            'ngrok-skip-browser-warning': 'true',
            'User-Agent': 'Voxel/2.0',
          },
          connectTimeout: const Duration(seconds: 10),
        );
      } else {
        _channel = WebSocketChannel.connect(
          Uri.parse(finalUrl),
        );
      }
      
      debugPrint('✅ WS Connection Initiated');
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _statusController.add(true);

      _channel!.stream.listen(
        (message) {
          debugPrint('📨 Received message: $message');
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('❌ WS Stream Error: $error');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('📡 WS Stream Closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      // Send initial connection message if your server expects it
      Future.delayed(Duration(milliseconds: 500), () {
        if (_isConnected) {
          debugPrint('📤 Sending initial join message');
          _send({
            'type': 'join',
            'payload': {
              'userId': userId,
              'username': 'User_$userId',
            }
          });
        }
      });

    } catch (e, stackTrace) {
      debugPrint('❌ WS Connection Failed: $e');
      debugPrint('Stack trace: $stackTrace');
      _isConnecting = false;
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    if (!_isConnected && _reconnectTimer != null) return; // Already reconnecting
    
    debugPrint('🔌 _handleDisconnect called. Was connected: $_isConnected');
    _isConnected = false;
    _statusController.add(false);
    _channel?.sink.close();
    _channel = null;
    
    // Exponential Backoff: 1s, 2s, 4s, 8s, max 30s
    final delaySeconds = pow(2, _reconnectAttempts).toInt().clamp(1, 30);
    _reconnectAttempts++;
    
    debugPrint('🔄 Reconnecting in ${delaySeconds}s... (Attempt $_reconnectAttempts)');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_isConnected && _lastUserId != null) {
         connect(_lastUserId!);
      }
    });
  }

  Stream<bool> subscribeConnectionStatus() => _statusController.stream;

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      final payload = data['payload'];

      debugPrint('📥 Message type: $type');

      if (type == 'move') {
        // Payload: {userId, x, y, avatarUrl, ...}
        // Check if it's a valid map
        if (payload is Map<String, dynamic>) {
           _updatePeer(payload);
        }
      } else if (type == 'leave') {
        if (payload is Map<String, dynamic>) {
          final userId = payload['userId'];
          if (userId != null) {
            _peers.remove(userId);
            _emitPositions();
          }
        }
      } else if (type == 'audio') {
        if (payload is Map<String, dynamic>) {
          _audioController.add(payload);
        }
      } else if (type == 'event_created') {
        if (payload is Map<String, dynamic>) {
          _eventController.add(payload);
        }
      } else if (type == 'events_list') {
        if (payload is List<dynamic>) {
          _eventsListController.add(payload);
        }
      } else if (type == 'session_update') {
        if (payload is Map<String, dynamic>) {
          _sessionController.add(payload);
        }
      } else if (type == 'webrtc_offer' || type == 'webrtc_answer' || type == 'webrtc_ice_candidate') {
        if (payload is Map<String, dynamic>) {
          // Add type to payload for easier processing in service
          final signalingData = Map<String, dynamic>.from(payload);
          signalingData['type'] = type;
          _signalingController.add(signalingData);
        }
      }
      // Handle 'join', 'leave' similarly if server sends them
      
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }

  void _updatePeer(Map<String, dynamic> data) {
    final userId = data['userId'];
    if (userId == null) {
      debugPrint('Received move message with no userId: $data');
      return;
    }
    
    // Convert generic map to entity with null safety
    final username = data['username'] as String? ?? 'User';
    final x = (data['x'] as num?)?.toDouble() ?? 500.0;
    final y = (data['y'] as num?)?.toDouble() ?? 500.0;
    final avatarUrl = data['avatarUrl'] as String? ?? '';
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    final isTalking = data['isTalking'] as bool? ?? false;
    
    final pos = AvatarPosition(
      userId: userId,
      username: username,
      x: x,
      y: y,
      updatedAt: DateTime.now(),
      avatarUrl: avatarUrl,
      latitude: lat,
      longitude: lng,
      isTalking: isTalking,
    );
    
    _peers[userId] = pos;
    _emitPositions();
  }

  void _emitPositions() {
    _positionController.add(_peers.values.toList());
  }

  @override
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _lastUserId = null;
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _peers.clear();
  }

  @override
  Stream<List<AvatarPosition>> subscribePositions() {
    return _positionController.stream;
  }
  
  @override
  AvatarPosition? getPeerPosition(String userId) => _peers[userId];

  @override
  AvatarPosition? getMyPosition() {
    if (_lastUserId == null) return null;
    // We don't store "me" in _peers generally to avoid self-collision in some logic,
    // but we can return it if it's there or if we have a special place for it.
    // In this codebase, the controller updates the repository with its position.
    return _peers[_lastUserId]; 
  }
  
  Stream<Map<String, dynamic>> subscribeSessionUpdates() {
    return _sessionController.stream;
  }

  @override
  void sendAudio(List<int> data) {
    if (_channel == null) {
      debugPrint('⚠️ Cannot send audio: channel is null');
      return;
    }
    _send({
      'type': 'audio',
      'payload': {
        'userId': _lastUserId,
        'data': base64Encode(data),
      }
    });
  }

  @override
  Stream<Map<String, dynamic>> subscribeAudio() => _audioController.stream;

  @override
  void createEvent(Map<String, dynamic> eventData) {
    _send({
      'type': 'create_event',
      'payload': eventData,
    });
  }

  @override
  Stream<Map<String, dynamic>> subscribeEvents() => _eventController.stream;

  @override
  Stream<List<dynamic>> subscribeEventsList() => _eventsListController.stream;

  @override
  Future<void> updateMyPosition(AvatarPosition position) async {
    if (_channel == null) {
      debugPrint('⚠️ Cannot update position: channel is null');
      return;
    }
    
    final msg = {
      'type': 'move',
      'payload': {
        'userId': position.userId,
        'username': position.username,
        'x': position.x,
        'y': position.y,
        'avatarUrl': position.avatarUrl,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isTalking': position.isTalking,
      }
    };
    
    _send(msg);
  }
  
  @override
  void sendSignaling(String type, String targetId, dynamic data) {
    if (_channel == null) return;
    
    _send({
      'type': type,
      'payload': {
        'targetId': targetId,
        'senderId': _lastUserId,
        'data': data,
      }
    });
  }

  @override
  Stream<Map<String, dynamic>> subscribeSignaling() => _signalingController.stream;
  
  // Session Methods
  void createSession(String gameType) {
    _send({
      'type': 'create_session',
      'payload': {'gameType': gameType}
    });
  }
  
  void joinSession(String sessionId) {
    _send({
      'type': 'join_session',
      'payload': {'sessionId': sessionId}
    });
  }
  
  void startGame(String sessionId) {
     _send({
      'type': 'start_game',
      'payload': {'sessionId': sessionId}
    });
  }

  void _send(Map<String, dynamic> msg) {
    try {
      if (_channel == null) {
        debugPrint('⚠️ Cannot send message: channel is null');
        return;
      }
      final jsonMsg = jsonEncode(msg);
      debugPrint('📤 Sending: $jsonMsg');
      _channel?.sink.add(jsonMsg);
    } catch (e) {
      debugPrint('❌ Failed to send WS message: $e');
    }
  }
}