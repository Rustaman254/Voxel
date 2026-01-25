import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../../domain/services/voice_chat_service.dart';
import '../../domain/repositories/world_repository.dart';
import 'package:voxel/data/repositories/socket_world_repository.dart';

class SocketVoiceChatService implements VoiceChatService {
  final WorldRepository _repository;
  final StreamController<VoiceChatState> _stateController = StreamController<VoiceChatState>.broadcast();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  VoiceChatState _currentState = const VoiceChatState();
  
  // Status flags
  bool _isPlayerInited = false;
  bool _isDisposed = false;
  
  // Audio queue for controlled playback
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
  
  // Audio Aggregation Buffer
  final BytesBuilder _aggregationBuffer = BytesBuilder();
  static const int _targetChunkSize = 2048; // ~64ms at 16kHz
  
  bool _isProcessingQueue = false;
  
  // Buffer management
  static const int maxQueueSize = 500; 
  static const int minQueueSize = 3; // Jitter buffer: wait for 3 chunks before playing
  int _droppedPackets = 0;
  int _packetCount = 0;
  bool _hasBufferedEnough = false; // To handle jitter

  SocketVoiceChatService(this._repository) {
    _currentState = const VoiceChatState();
    _initPlayer();
    
    // Listen for incoming audio using the public repository method
    // This is the correct way to interact with the repository!
    _repository.subscribeAudio().listen((packet) {
       _handleIncomingAudio(packet);
    }, onError: (e) {
      debugPrint('Error in audio subscription: $e');
    });
  }

  Future<void> _initPlayer() async {
    try {
      await _player.openPlayer();
      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 16000, // Lower rate is better for voice over network
        bufferSize: 4096, 
        interleaved: false,
      );
      _isPlayerInited = true;
      debugPrint('✅ Voice chat player initialized successfully');
      
      // Start queue processor
      _startQueueProcessor();
    } catch (e) {
      debugPrint('❌ Error initializing voice player: $e');
      _emit(VoiceChatState(status: VoiceChatStatus.disconnected));
    }
  }
  
  // No more Timer
  void _startQueueProcessor() {
    // No-op: Processor is now event-driven
  }
  
  bool _isDraining = false;

  Future<void> _drainAudioQueue() async {
    // Prevent concurrent drain loops
    if (_isDraining || _isDisposed || !_isPlayerInited) return;
    
    // Initial buffering check: don't start draining until we have enough data
    // UNLESS we are already playing (queue isn't empty, just got new data)
    // But simplistic check: if queue is very small and we might risk underrun, wait?
    // For now, simpler is better: if we have data, feed it.
    // However, to prevent "scratching" at start, we enforce minQueueSize only if we were effectively idle.
    
    // Actually, feedFromStream manages the player buffer. We should just feed it as fast as we can.
    // The "minQueueSize" is useful mainly to not start the VERY FIRST playback too early.
    
    _isDraining = true;
    
    try {
      while (_audioQueue.isNotEmpty && !_isDisposed) {
        // If we hit a gap, reset the "enough buffered" flag to catch up for jitter
        if (_audioQueue.length < minQueueSize && !_hasBufferedEnough) {
          // Keep waiting for more
           break;
        }

        final chunk = _audioQueue.removeFirst();
        
        try {
           await _player.feedFromStream(chunk);
        } catch (e) {
           debugPrint('⚠️ Error feeding player: $e');
           await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    } finally {
      _isDraining = false;
      
      if (_audioQueue.isEmpty) {
        _hasBufferedEnough = false; // Reset jitter buffer for next burst
      }

      if (_audioQueue.isNotEmpty && !_isDisposed) {
         _drainAudioQueue();
      }
    }
  }

  void _emit(VoiceChatState state) {
    if (_isDisposed) return;
    _currentState = state;
    _stateController.add(state);
  }

  @override
  Stream<VoiceChatState> get state => _stateController.stream;

  @override
  Future<void> joinGroup(Set<String> userIds) async {
    // Clear queue when joining new group
    _audioQueue.clear();
    _droppedPackets = 0;
    
    _emit(_currentState.copyWith(
      connectedUserIds: userIds, 
      status: VoiceChatStatus.connected
    ));
  }

  @override
  Future<void> leaveGroup() async {
    // Clear queue when leaving
    _audioQueue.clear();
    _droppedPackets = 0;
    
    _emit(_currentState.copyWith(
      connectedUserIds: {}, 
      status: VoiceChatStatus.connected
    ));
  }

  void _handleIncomingAudio(Map<String, dynamic> packet) {
    try {
      final senderId = packet['userId'] as String?;
      final dataBase64 = packet['data'] as String?;
      
      if (senderId == null || dataBase64 == null) return;

      // Decode audio data
      final data = base64Decode(dataBase64);
      
      // Heartbeat Log: Only print every 50 packets to avoid spam
      _packetCount++;
      if (_packetCount % 50 == 0) {
        debugPrint('👂 Receiving Audio from $senderId. Nearby: ${_currentState.connectedUserIds.contains(senderId)}');
      }

      // 1. Get positions for distance calculation
      final myPos = _repository.getMyPosition();
      final senderPos = _repository.getPeerPosition(senderId);
      
      double volumeFactor = 1.0;
      
      if (myPos != null && senderPos != null) {
        final dist = sqrt(pow(senderPos.x - myPos.x, 2) + pow(senderPos.y - myPos.y, 2));
        const maxDist = 400.0;
        
        if (dist > maxDist) {
          // Too far, drop packet
          return;
        }
        
        // Linear attenuation (Google Meet style)
        // 1.0 at dist=0, 0.0 at dist=400
        volumeFactor = (1.0 - (dist / maxDist)).clamp(0.0, 1.0);
        
        // Optional: Log distance/volume occasionally
        if (_packetCount % 100 == 0) {
           debugPrint('🔊 Distance to $senderId: ${dist.toStringAsFixed(1)} units. Volume: ${(volumeFactor * 100).toInt()}%');
        }
      }

      // 2. Scale Volume
      if (volumeFactor < 0.99) {
        _scalePcmVolume(data, volumeFactor);
      }

      // 3. AGGREGATION: Don't feed tiny packets to the player. Buffer them.
      _aggregationBuffer.add(data);
      
      if (_aggregationBuffer.length >= _targetChunkSize) {
        final bigChunk = _aggregationBuffer.takeBytes();
        
        // Drop oldest packets if queue is full (prevent memory overflow/delay)
        if (_audioQueue.length >= maxQueueSize) {
          _droppedPackets++;
          if (_droppedPackets % 50 == 0) {
            debugPrint('⚠️ Audio Queue Overwhelmed: Dropped $_droppedPackets packets');
          }
          _audioQueue.removeFirst();
        }
        
        // Add to queue
        _audioQueue.add(bigChunk);
        
        // JITTER CONTROL: Wait for minQueueSize before starting to play
        if (!_hasBufferedEnough && _audioQueue.length >= minQueueSize) {
          _hasBufferedEnough = true;
          // debugPrint('🌊 Jitter buffer filled (${_audioQueue.length}), starting playback');
        }
 
         // START DRAINING: Only if jitter buffer is ready
         if (!_isDraining && _hasBufferedEnough) {
           _drainAudioQueue();
         }
       }
      
    } catch (e) {
      debugPrint('❌ Error handling incoming audio: $e');
    }
  }

  // Helper method to be called from the Mic listener in WorldScreen
  void sendAudioChunk(List<int> chunk) {
    if (_isDisposed) return;
    
    try {
      _repository.sendAudio(chunk);
    } catch (e) {
      debugPrint('❌ Error sending audio chunk: $e');
    }
  }

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    
    _audioQueue.clear();
    
    try {
      if (_isPlayerInited) {
        await _player.stopPlayer();
        await _player.closePlayer();
      }
    } catch (e) {
      debugPrint('Error disposing player: $e');
    }
    
    await _stateController.close();
    debugPrint('🎙️ Voice chat service disposed');
  }
}

extension on VoiceChatState {
  VoiceChatState copyWith({VoiceChatStatus? status, Set<String>? connectedUserIds}) {
    return VoiceChatState(
      status: status ?? this.status,
      connectedUserIds: connectedUserIds ?? this.connectedUserIds,
    );
  }
}

void _scalePcmVolume(Uint8List data, double factor) {
  // Ensure we don't crash on invalid data
  if (data.length % 2 != 0) return;
  
  final buffer = data.buffer.asInt16List(data.offsetInBytes, data.length ~/ 2);
  for (int i = 0; i < buffer.length; i++) {
    // Rounding is better than truncating for audio
    buffer[i] = (buffer[i] * factor).round().toInt();
  }
}
