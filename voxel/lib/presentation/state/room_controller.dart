import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/entities/room.dart';
import '../../data/repositories/room_repository.dart';
import '../../domain/services/voice_chat_service.dart';
import '../../data/services/webrtc_voice_service.dart';
import '../../domain/repositories/world_repository.dart';
import 'voice_chat_provider.dart';
import 'world_controller.dart';
import 'peers_provider.dart';
import '../../data/repositories/socket_world_repository.dart';
import 'auth_notifier.dart';

class RoomState {
  final bool isLoading;
  final List<Room> rooms;
  final Room? currentRoom;
  final String? error;

  const RoomState({
    this.isLoading = false,
    this.rooms = const [],
    this.currentRoom,
    this.error,
  });

  RoomState copyWith({
    bool? isLoading,
    List<Room>? rooms,
    Room? currentRoom,
    String? error,
  }) {
    return RoomState(
      isLoading: isLoading ?? this.isLoading,
      rooms: rooms ?? this.rooms,
      currentRoom: currentRoom, // Allow setting to null
      error: error,
    );
  }
}

class RoomController extends StateNotifier<RoomState> {
  final RoomRepository _repository;
  final VoiceChatService _voiceService;
  final WorldRepository _worldRepository;
  final Ref _ref;

  RoomController(this._repository, this._voiceService, this._worldRepository, this._ref) : super(const RoomState()) {
    _initModerationListener();
  }

  void _initModerationListener() {
    if (_worldRepository is SocketWorldRepository) {
      (_worldRepository as SocketWorldRepository).subscribeModeration().listen((data) {
        final type = data['type'];
        final roomId = data['roomId'];
        if (state.currentRoom?.id == roomId) {
          if (type == 'kicked' || type == 'banned') {
            leaveRoom();
          }
        }
      });
    }
  }

  Future<void> loadRooms() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rooms = await _repository.getRooms();
      state = state.copyWith(isLoading: false, rooms: rooms);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createRoom(String name, String description, bool isPrivate, {double x = 0, double y = 0, double latitude = 0, double longitude = 0}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final room = await _repository.createRoom(name, description, isPrivate, x: x, y: y, latitude: latitude, longitude: longitude);
      state = state.copyWith(
        isLoading: false, 
        rooms: [...state.rooms, room], 
        currentRoom: room,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> joinRoom(String roomId) async {
     state = state.copyWith(isLoading: true, error: null);
     try {
       // Call API to join room
       final room = await _repository.joinRoom(roomId);
       
       // Send WebSocket message to switch session
       if (_worldRepository is SocketWorldRepository) {
         (_worldRepository as SocketWorldRepository).sendMessage({
           'type': 'join_room',
           'payload': {'roomId': roomId},
         });
       }

       // Connect to room voice channel
       await _voiceService.joinChannel(roomId);
       
       state = state.copyWith(isLoading: false, currentRoom: room);

       // Initiate WebRTC calls to other members who might be in the room
       if (_voiceService is WebrtcVoiceService) {
         for (var member in room.members) {
           final myId = _ref.read(authProvider).user?.id;
           if (member.userId != myId) {
              (_voiceService as WebrtcVoiceService).initiateCall(member.userId);
           }
         }
       }
     } catch (e) {
       state = state.copyWith(isLoading: false, error: e.toString());
     }
  }
  
  Future<void> leaveRoom() async {
    final currentRoomId = state.currentRoom?.id;
    if (currentRoomId == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      // Call API to leave room
      await _repository.leaveRoom(currentRoomId);
      
      // Send WebSocket message to return to global session
      if (_worldRepository is SocketWorldRepository) {
        (_worldRepository as SocketWorldRepository).sendMessage({
          'type': 'leave_room',
          'payload': {},
        });
      }

      // Leave voice channel
      await _voiceService.leaveChannel();
      
      state = state.copyWith(isLoading: false, currentRoom: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addMember(String roomId, String userId, List<String> permissions) async {
    try {
      await _repository.addMember(roomId, userId, permissions);
      // Refresh room data to get updated key
      final updatedRoom = await _repository.getRoom(roomId);
      _updateRoomInState(updatedRoom);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> removeMember(String roomId, String userId) async {
    try {
      await _repository.removeMember(roomId, userId);
      final updatedRoom = await _repository.getRoom(roomId);
      _updateRoomInState(updatedRoom);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void _updateRoomInState(Room updatedRoom) {
     final updatedRooms = state.rooms.map((r) => r.id == updatedRoom.id ? updatedRoom : r).toList();
     state = state.copyWith(
       rooms: updatedRooms,
       currentRoom: state.currentRoom?.id == updatedRoom.id ? updatedRoom : state.currentRoom,
     );
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await _repository.deleteRoom(roomId);
      state = state.copyWith(
        rooms: state.rooms.where((r) => r.id != roomId).toList(),
      );
      if (state.currentRoom?.id == roomId) {
        leaveRoom();
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void centerMapOnRoom(Room room) {
    // This method will be called from the discover dialog to center the map on a room
    // The actual map centering is handled by the world controller
    // We just need to notify the world controller to move the camera
    _ref.read(worldControllerProvider.notifier).moveCameraTo(room.x, room.y);
  }

  void kickUser(String roomId, String targetUserId) {
    if (_worldRepository is SocketWorldRepository) {
      (_worldRepository as SocketWorldRepository).kickUser(roomId, targetUserId);
    }
  }

  void banUser(String roomId, String targetUserId) {
    if (_worldRepository is SocketWorldRepository) {
      (_worldRepository as SocketWorldRepository).banUser(roomId, targetUserId);
    }
  }
}

final roomRepositoryProvider = Provider((ref) => RoomRepository());

final roomControllerProvider = StateNotifierProvider<RoomController, RoomState>((ref) {
  final repository = ref.watch(roomRepositoryProvider);
  final voiceService = ref.watch(voiceChatServiceProvider);
  final worldRepo = ref.watch(worldRepositoryProvider);
  return RoomController(repository, voiceService, worldRepo, ref);
});

