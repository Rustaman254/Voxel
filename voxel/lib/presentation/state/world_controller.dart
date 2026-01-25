import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../domain/entities/avatar_position.dart';
import '../../domain/repositories/world_repository.dart';
import '../../domain/services/location_service.dart';
import '../../domain/services/voice_chat_service.dart';
import '../../data/repositories/socket_world_repository.dart';
import 'auth_notifier.dart';
import 'location_provider.dart';
import 'peers_provider.dart';

// State class for the world view (camera)
class WorldState {
  final double cameraX;
  final double cameraY;
  final double zoom;
  final AvatarPosition? myPosition;
  final String? activeEventId;
  final bool? _isGpsMode;
  final bool isMuted;
  final bool isManuallyMuted;
  
  bool get isGpsMode => _isGpsMode ?? false;

  const WorldState({
    this.cameraX = 0.0,
    this.cameraY = 0.0,
    this.zoom = 1.0,
    this.myPosition,
    this.activeEventId,
    bool? isGpsMode,
    this.isMuted = true,
    this.isManuallyMuted = false,
  }) : _isGpsMode = isGpsMode;

  WorldState copyWith({
    double? cameraX,
    double? cameraY,
    double? zoom,
    AvatarPosition? myPosition,
    String? activeEventId,
    bool? isGpsMode,
    bool? isMuted,
    bool? isManuallyMuted,
  }) {
    return WorldState(
      cameraX: cameraX ?? this.cameraX,
      cameraY: cameraY ?? this.cameraY,
      zoom: zoom ?? this.zoom,
      myPosition: myPosition ?? this.myPosition,
      activeEventId: activeEventId ?? this.activeEventId,
      isGpsMode: isGpsMode ?? this.isGpsMode,
      isMuted: isMuted ?? this.isMuted,
      isManuallyMuted: isManuallyMuted ?? this.isManuallyMuted,
    );
  }
}

class WorldController extends StateNotifier<WorldState> {
  final WorldRepository _worldRepository;
  final LocationService _locationService;
  final VoiceChatService? _voiceChatService;
  final String? _userId;
  final String _username;
  final String _avatarUrl;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<List<AvatarPosition>>? _peersSubscription;
  StreamSubscription<VoiceChatState>? _voiceSubscription;
  Timer? _heartbeatTimer;

  WorldController(this._worldRepository, this._locationService, this._voiceChatService, this._userId, {String username = '', String avatarUrl = ''}) 
      : _username = username,
        _avatarUrl = avatarUrl, 
        super(const WorldState()) {
    if (_userId != null) {
      _initMyPosition();
      _worldRepository.connect(_userId!).then((_) {
         // CRITICAL: Re-send position after connection is established
         // This makes us visible to everyone else in the global world immediately
         if (state.myPosition != null) {
           debugPrint('📍 Sending initial position sync');
           _worldRepository.updateMyPosition(state.myPosition!);
         }
      });
      _initLocationTracking();
      _initPeersTracking();
      _initVoiceTracking();
      _startHeartbeat();
    }
  }

  void _initVoiceTracking() {
    if (_voiceChatService != null) {
      _voiceSubscription = _voiceChatService!.state.listen((vState) {
         setTalking(vState.isTalking);
      });
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (state.myPosition != null) {
        _worldRepository.updateMyPosition(state.myPosition!);
      }
    });
  }

  void _initPeersTracking() {
    _peersSubscription = _worldRepository.subscribePositions().listen((peers) {
       // Proximity logic is now handled by proximityLogicProvider in peers_provider.dart
       // We only need to check if ANYONE is near for auto-mute UI
       _checkAutoMute(peers);
    });
  }

  void _checkAutoMute(List<AvatarPosition> peers) {
    if (state.myPosition == null) return;
    final me = state.myPosition!;
    
    final anyoneNear = peers.any((p) {
       if (p.userId == me.userId) return false;
       final dist = sqrt(pow(p.x - me.x, 2) + pow(p.y - me.y, 2));
       return dist < 400.0; 
    });

    if (anyoneNear && state.isMuted) {
       debugPrint('👤 Someone became nearby! Auto-unmuting...');
    }

    if (!anyoneNear) {
      if (!state.isMuted) state = state.copyWith(isMuted: true);
    } else {
      if (!state.isManuallyMuted && state.isMuted) {
        state = state.copyWith(isMuted: false);
      }
    }
  }
  
  void _initMyPosition() {
    if (_userId == null) return;
    
     // Start at center
     final pos = AvatarPosition(
        userId: _userId!,
        username: _username,
        x: 500,
        y: 500,
        updatedAt: DateTime.now(),
        avatarUrl: _avatarUrl,
      );
     state = state.copyWith(myPosition: pos, cameraX: 500, cameraY: 500);
     _worldRepository.updateMyPosition(pos);
  }

  void _initLocationTracking() async {
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) return;

    _locationSubscription = _locationService.getPositionStream().listen((position) {
      if (state.myPosition == null) return;

      final current = state.myPosition!;
      
      // If GPS mode is on, we also update X/Y based on Lat/Long
      double? nextX = current.x;
      double? nextY = current.y;
      
      if (state.isGpsMode) {
        // Simple mapping: 1 unit in Voxel = small change in Lat/Long
        // Center on some reference point
        const refLat = -1.28; 
        const refLong = 36.82;
        nextX = 500 + (position.longitude - refLong) * 50000;
        nextY = 500 + (position.latitude - refLat) * 50000;
      }

      final newPos = current.copyWith(
        latitude: position.latitude,
        longitude: position.longitude,
        x: nextX,
        y: nextY,
        updatedAt: DateTime.now(),
      );
      
      state = state.copyWith(myPosition: newPos);
      _worldRepository.updateMyPosition(newPos);
    });
  }

  void panCamera(double dx, double dy) {
    // Adjust sensitivity by zoom
    final scale = 1.0 / state.zoom;
    state = state.copyWith(
      cameraX: state.cameraX - (dx * scale),
      cameraY: state.cameraY - (dy * scale),
    );
  }

  void zoomCamera(double scaleChange) {
    double newZoom = state.zoom * scaleChange;
    // Clamp zoom
    if (newZoom < 0.1) newZoom = 0.1;
    if (newZoom > 5.0) newZoom = 5.0;
    state = state.copyWith(zoom: newZoom);
  }

  void toggleMute() {
    final newMute = !state.isMuted;
    state = state.copyWith(
      isMuted: newMute,
      isManuallyMuted: newMute, // If user toggles, we consider it a manual choice
    );
    
    // Actually mute/unmute the microphone
    _voiceChatService?.setMuted(newMute);
  }

  void toggleGpsMode() {
    state = state.copyWith(isGpsMode: !state.isGpsMode);
  }

  void enterEventWorld(String id) {
    state = state.copyWith(activeEventId: id);
  }

  void exitEventWorld() {
    state = state.copyWith(activeEventId: null);
  }

  void recenterCamera() {
    if (state.myPosition == null) return;
    state = state.copyWith(
      cameraX: state.myPosition!.x,
      cameraY: state.myPosition!.y,
      zoom: 1.0, // Optional: reset zoom too?
    );
  }

  void moveCameraTo(double x, double y) {
    state = state.copyWith(cameraX: x, cameraY: y);
  }

  DateTime _lastPositionUpdate = DateTime.now();
  
  void moveMyAvatar(double dx, double dy) {
    if (state.myPosition == null) return;
    
    final scale = 1.0 / state.zoom;
    final current = state.myPosition!;
    final newPos = current.copyWith(
      x: current.x + (dx * scale), 
      y: current.y + (dy * scale),
      updatedAt: DateTime.now(),
    );
    
    // Always update local state immediately for smooth UI
    state = state.copyWith(myPosition: newPos);
    
    // Throttle network updates (max 30 per second = 33ms)
    if (DateTime.now().difference(_lastPositionUpdate).inMilliseconds > 33) {
      _lastPositionUpdate = DateTime.now();
      _worldRepository.updateMyPosition(newPos);
    }
  }

  // Called when drag ends to ensure final position is synced
  void forcePositionSync() {
    if (state.myPosition == null) return;
    _worldRepository.updateMyPosition(state.myPosition!);
  }

  void setTalking(bool isTalking) {
    if (state.myPosition == null || state.myPosition!.isTalking == isTalking) return;
    
    final newPos = state.myPosition!.copyWith(
      isTalking: isTalking,
      updatedAt: DateTime.now(),
    );
    state = state.copyWith(myPosition: newPos);
    
    // Throttle voice status updates slightly too (though less critical)
    // We want this snappy, but not noise
    _worldRepository.updateMyPosition(newPos);
  }
  
  @override
  void dispose() {
    _locationSubscription?.cancel();
    _peersSubscription?.cancel();
    _voiceSubscription?.cancel();
    _heartbeatTimer?.cancel();
    _worldRepository.disconnect();
    super.dispose();
  }
}

final worldRepositoryProvider = Provider<WorldRepository>((ref) => SocketWorldRepository());

final worldControllerProvider = StateNotifierProvider<WorldController, WorldState>((ref) {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(worldRepositoryProvider);
  final locationService = ref.watch(locationServiceProvider);
  final userId = authState.value?.id;
  final username = authState.value?.displayName ?? 'User';
  final avatarUrl = authState.value?.avatarUrl ?? '';
  final voiceService = ref.watch(voiceChatServiceProvider);
  
  return WorldController(repo, locationService, voiceService, userId, username: username, avatarUrl: avatarUrl);
});

final connectionStatusProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(worldRepositoryProvider);
  if (repo is SocketWorldRepository) {
    return repo.subscribeConnectionStatus();
  }
  return Stream.value(true);
});
