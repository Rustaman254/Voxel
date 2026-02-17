import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/voxel_avatar.dart';
import '../painters/forest_generator.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_notifier.dart';
import '../state/world_controller.dart';
import '../state/game_session_provider.dart';
import '../state/peers_provider.dart';
import '../painters/world_painter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'dart:math';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../state/event_notifier.dart';
import 'create_event_screen.dart';
import 'event_details_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'game_setup_screen.dart';
import '../../domain/models/event_model.dart';
import '../../domain/entities/avatar_position.dart';
import '../widgets/discover_events_dialog.dart';
import 'discover_screen.dart';
import '../widgets/active_users_dialog.dart';

import 'chat_screen.dart';
import 'profile_screen.dart';
import 'messages_list_screen.dart';
import 'room_creation_screen.dart';
import 'room_details_screen.dart';
import '../widgets/notification_dialog.dart';
import '../state/notification_service.dart';
import '../state/room_controller.dart';
import '../widgets/room_marker.dart';
import '../state/friends_provider.dart';
import 'friends_list_screen.dart';
import '../widgets/shake_animated_widget.dart';
import 'package:heroicons/heroicons.dart';

class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}
class _WorldScreenState extends ConsumerState<WorldScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomControllerProvider.notifier).loadRooms();
    });
  }

  // Base zoom for scaling
  double _baseZoom = 1.0;

  // Interaction State
  VoxelEvent? _selectedEvent;
  bool _isCollisionPopup = false;

  // Map Controller for Real World Mode (OpenStreetMap)
  final MapController _mapController = MapController();
  bool _userManuallyMovedMap = false; // Track if user manually moved the map
  
  // Routing
  List<LatLng> _routePoints = [];
  bool _isFetchingRoute = false;

  // Bottom Navigation
  int _selectedNavIndex = 0;

  Future<void> _fetchRoute(LatLng destination) async {
    final myPos = ref.read(worldControllerProvider).myPosition;
    if (myPos == null) return;
    
    setState(() => _isFetchingRoute = true);
    
    try {
      // OSRM Public API (Demo only - use your own server in prod)
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${myPos.longitude},${myPos.latitude};${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson'
      );
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final geometry = data['routes'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;
        
        setState(() {
          _routePoints = coordinates.map((c) => LatLng(c[1] as double, c[0] as double)).toList();
          _isFetchingRoute = false;
        });
        
        // Fit bounds to show route
        if (_routePoints.isNotEmpty) {
           final bounds = LatLngBounds.fromPoints(_routePoints);
           _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
        }
      }
    } catch (e) {
      debugPrint('Error fetching route: $e');
      setState(() => _isFetchingRoute = false);
      // Fallback: straight line
      setState(() {
        _routePoints = [
          LatLng(myPos.latitude, myPos.longitude),
          destination
        ];
      });
    }
  }

  // Voice Visualization - Removed local mic handling

  void _showEventDiscovery(
    BuildContext context,
    WidgetRef ref,
    List<VoxelEvent> events,
  ) {
    showDialog(
      context: context,
      builder: (context) => const DiscoverEventsDialog(),
    );
  }

  void _showUserProfile(BuildContext context, AvatarPosition peer) {
    final myUserId = ref.read(authProvider).user?.id;
    
    // If viewing own profile, navigate to profile screen
    if (peer.userId == myUserId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileScreen(),
        ),
      );
      return;
    }
    
    // Otherwise show peer profile modal
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 400,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getProfileColor(peer.userId),
                  width: 4,
                ),
              ),
              child: CircleAvatar(
                backgroundImage: peer.avatarUrl.isNotEmpty
                    ? NetworkImage(peer.avatarUrl)
                    : null,
                backgroundColor: Colors.grey[200],
                radius: 46,
                child: peer.avatarUrl.isEmpty
                    ? Text(
                        peer.username.isNotEmpty
                            ? peer.username[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              peer.username,
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              '@${peer.userId.length > 8 ? peer.userId.substring(0, 8) : peer.userId}',
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildProfileAction(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  color: const Color(0xFF00D2FF),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (c) => ChatScreen(
                          peerId: peer.userId,
                          peerName: peer.username,
                        )
                      )
                    );
                  },
                ),
                _buildProfileAction(
                  icon: Icons.person_add_rounded,
                  label: 'Add Friend',
                  color: const Color(0xFFFFCC00),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend request sent!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers
    final worldState = ref.watch(worldControllerProvider);
    final peersAsync = ref.watch(peersStreamProvider);
    final voiceStateAsync = ref.watch(voiceStateProvider);
    final events = ref.watch(eventProvider);

    // Don't auto-center map when GPS updates - only center on LOCATE button
    // This allows users to freely pan the map without it jumping back

    // Helper to get valid LatLng
    LatLng getValidLatLng(double lat, double lng) {
      if (lat == 0 && lng == 0)
        return const LatLng(-1.2921, 36.8219); // Default to Nairobi
      return LatLng(lat, lng);
    }

    // Ensure proximity logic is active
    ref.watch(proximityLogicProvider);

    final peers = peersAsync.value ?? [];

    // Filter peers if in an event world (Simple local filter for now)
    final activeEventId = worldState.activeEventId;
    final activeEvent = activeEventId != null
        ? events.where((e) => e.id == activeEventId).firstOrNull
        : null;

    // Filter peers based on GPS mode and visibility
    var filteredPeers = activeEventId != null
        ? peers // In a real app, the backend would filter this, but we'll show all for now or filter by 'event_id' property if exists
        : peers;

    // In GPS mode: Only show users who have GPS ON (isVisible = true means they have GPS on)
    // When GPS is off: User is invisible to others but can see themselves
    if (worldState.isGpsMode) {
      filteredPeers = filteredPeers
          .where(
            (p) =>
                p.isVisible && // Only show users with GPS ON
                (worldState.trackedUserIds.isEmpty ||
                    worldState.trackedUserIds.contains(p.userId)) &&
                p.latitude != 0 &&
                p.longitude != 0,
          )
          .toList();
    }

    // Filter events: Only show GPS events when in GPS mode, only show non-GPS events when GPS is off
    final filteredEvents = events.where((e) {
      if (worldState.isGpsMode) {
        // In GPS mode: Show only GPS events with valid coordinates
        return e.isGpsEvent && e.latitude != 0 && e.longitude != 0;
      } else {
        // In virtual mode: Show only non-GPS events
        return !e.isGpsEvent;
      }
    }).toList();

    // Proximity logic for UI
    final isNearSomeone = filteredPeers.any((p) {
      final d = Geolocator.distanceBetween(
        worldState.myPosition?.latitude ?? 0,
        worldState.myPosition?.longitude ?? 0,
        p.latitude,
        p.longitude,
      );
      return d < 30.0;
    });
    final voiceState = voiceStateAsync.value;
    final isTalking = voiceState?.isTalking ?? false;
    final connectedIds = voiceState?.connectedUserIds ?? {};

    // Map IDs to names
    final connectedNames = peers
        .where((p) => connectedIds.contains(p.userId))
        .map((p) => p.username)
        .toList();

    String connectionTitle = 'Not near anyone';
    if (connectedNames.isNotEmpty) {
      if (connectedNames.length <= 2) {
        connectionTitle = 'Speaking to: ${connectedNames.join(', ')}';
      } else {
        connectionTitle =
            'Speaking to: ${connectedNames.take(2).join(', ')}...';
      }
    } else if (isNearSomeone) {
      connectionTitle = 'Connecting...';
    }

    final isCameraAtPlayer =
        worldState.myPosition != null &&
        (worldState.cameraX - worldState.myPosition!.x).abs() < 200 &&
        (worldState.cameraY - worldState.myPosition!.y).abs() < 200;

    final isOffline = ref.watch(connectionStatusProvider).value == false;
    final isLocationMissing =
        worldState.isGpsMode && (worldState.myPosition?.latitude == 0);

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final centerX = constraints.maxWidth / 2;
          final centerY = constraints.maxHeight / 2;

          // Helper to map world to screen
          Offset worldToScreen(double wx, double wy) {
            return Offset(
              centerX + (wx - worldState.cameraX) * worldState.zoom,
              centerY + (wy - worldState.cameraY) * worldState.zoom,
            );
          }

          return Stack(
            children: [
              // 1. Game World Grid with Input Handler
              // 1. Game World Grid (Virtual) OR Real Map (GPS)
              if (!worldState.isGpsMode)
                WorldInputHandler(
                  ref: ref,
                  onZoomStart: () {
                    _baseZoom = ref.read(worldControllerProvider).zoom;
                  },
                  onZoomUpdate: (scale) {
                    ref
                        .read(worldControllerProvider.notifier)
                        .zoomCamera(
                          _baseZoom *
                              scale /
                              ref.read(worldControllerProvider).zoom,
                        );
                  },
                  child: RepaintBoundary(
                    child: CustomPaint(
                      size: Size.infinite,
                      painter: WorldPainter(
                        cameraX: worldState.cameraX,
                        cameraY: worldState.cameraY,
                        zoom: worldState.zoom,
                        myPosition: worldState.myPosition,
                        peers: peers,
                        voxelTheme: activeEvent?.voxelTheme,
                        isEventWorld: activeEventId != null,
                      ),
                    ),
                  ),
                )
              else
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: getValidLatLng(
                      worldState.myPosition?.latitude ?? 0,
                      worldState.myPosition?.longitude ?? 0,
                    ),
                    initialZoom: 15.0,
                    minZoom: 3.0,
                    maxZoom: 18.0,
                    onTap: (tapPosition, point) {
                      // Handle map taps if needed
                    },
                    onMapReady: () {
                      // Center map on user's position when GPS is enabled
                      if (worldState.isGpsMode &&
                          worldState.myPosition != null &&
                          worldState.myPosition!.latitude != 0 &&
                          worldState.myPosition!.longitude != 0) {
                        _mapController.move(
                          LatLng(
                            worldState.myPosition!.latitude,
                            worldState.myPosition!.longitude,
                          ),
                          15.0,
                        );
                        // Reset manual movement flag when GPS is connected
                        _userManuallyMovedMap = false;
                      }
                    },
                    onPositionChanged: (position, hasGesture) {
                      // Track if user manually moved the map
                      if (hasGesture) {
                        _userManuallyMovedMap = true;
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.voxel',
                      maxZoom: 19,
                    ),
                    if (_routePoints.isNotEmpty && worldState.isGpsMode)
                      PolylineLayer(
                        polylines: <Polyline<Object>>[
                          Polyline<Object>(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: const Color(0xFFB452FF),
                            pattern: const StrokePattern.dotted(),
                          ),
                        ],
                      ),
                    // Room Markers on GPS Map
                    if (worldState.isGpsMode)
                      MarkerLayer(
                        markers: ref.watch(roomControllerProvider).rooms
                            .where((room) => room.latitude != 0 && room.longitude != 0)
                            .map((room) {
                          return Marker(
                            point: LatLng(room.latitude, room.longitude),
                            width: 200,
                            height: 80,
                            child: GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (c) => RoomDetailsScreen(room: room),
                                );
                              },
                              child: RoomMarker(
                                room: room,
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (c) => RoomDetailsScreen(room: room),
                                  );
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    // Event Markers on GPS Map
                    if (worldState.isGpsMode)
                      MarkerLayer(
                        markers: filteredEvents
                            .where((event) => event.latitude != 0 && event.longitude != 0)
                            .map((event) {
                          return Marker(
                            point: LatLng(event.latitude, event.longitude),
                            width: 80,
                            height: 80,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => EventDetailsScreen(eventId: event.id),
                                  ),
                                );
                              },
                              child: _EventMarker(event: event),
                            ),
                          );
                        }).toList(),
                      ),
                    // User Position Markers on GPS Map
                    if (worldState.isGpsMode && worldState.myPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              worldState.myPosition!.latitude,
                              worldState.myPosition!.longitude,
                            ),
                            width: 60,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFB452FF),
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFB452FF).withOpacity(0.5),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Other Users' Position Markers on GPS Map
                    if (worldState.isGpsMode)
                      MarkerLayer(
                        markers: filteredPeers
                            .where((peer) => 
                                peer.latitude != 0 && 
                                peer.longitude != 0 &&
                                peer.userId != worldState.myPosition?.userId)
                            .map((peer) {
                          return Marker(
                            point: LatLng(peer.latitude, peer.longitude),
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              onTap: () => _showUserProfile(context, peer),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _getProfileColor(peer.userId),
                                  border: Border.all(
                                    color: peer.isTalking ? Colors.green : Colors.white,
                                    width: peer.isTalking ? 4 : 3,
                                  ),
                                ),
                                child: peer.avatarUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          peer.avatarUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              // 2. Peers & Events (Only show non-map overlay if in Virtual Mode)
              if (!worldState.isGpsMode) ...[
                ...filteredPeers
                    .where((p) => p.userId != worldState.myPosition?.userId)
                    .map((peer) {
                      final pos = worldToScreen(peer.x, peer.y);
                      final zoom = worldState.zoom;
                      const baseSize = 60.0;

                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        left: pos.dx - (baseSize / 2 * zoom),
                        top: pos.dy - (baseSize * 2 * zoom),
                        child: Transform.scale(
                          scale: zoom,
                          alignment: Alignment.bottomCenter,
                          child: RepaintBoundary(
                            child: GestureDetector(
                              onTap: () => _showUserProfile(context, peer),
                              child: _AvatarCircle(
                                url: peer.avatarUrl,
                                isTalking: peer.isTalking,
                                name: peer.username,
                                color: _getProfileColor(peer.userId),
                                size: baseSize,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
              ],

              // Room Markers in Virtual World
              if (!worldState.isGpsMode && activeEventId == null)
                ...ref.watch(roomControllerProvider).rooms
                    .where((room) => room.x != 0 || room.y != 0)
                    .map((room) {
                  final pos = worldToScreen(room.x, room.y);
                  return Positioned(
                    left: pos.dx - 100,
                    top: pos.dy - 80,
                    child: Transform.scale(
                      scale: worldState.zoom,
                      child: RoomMarker(
                        room: room,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (c) => RoomDetailsScreen(room: room),
                          );
                        },
                      ),
                    ),
                  );
                }),

              if (!worldState.isGpsMode && activeEventId == null)
                ...events.map((e) {
                  final pos = worldToScreen(e.x, e.y);
                  return Positioned(
                    left: pos.dx - 40,
                    top: pos.dy - 40,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEvent = e;
                          _isCollisionPopup = false;
                        });
                      },
                      child: _EventMarker(event: e),
                    ),
                  );
                }),

              // 2.5 Event Interaction Bubble
              if (_selectedEvent != null && !worldState.isGpsMode) ...[
                (() {
                  final pos = worldToScreen(
                    _selectedEvent!.x,
                    _selectedEvent!.y,
                  );
                  final user = ref.read(authProvider).user;
                  final isCreator = user?.id == _selectedEvent!.creatorId;

                  return Positioned(
                    left: pos.dx - 80,
                    top: pos.dy - 180,
                    child: _SquareInfoBubble(
                      title: _isCollisionPopup
                          ? 'ENTER EVENT'
                          : _selectedEvent!.title,
                      description: _isCollisionPopup
                          ? 'You are at the event location!'
                          : _selectedEvent!.description,
                      buttonText: _isCollisionPopup ? 'ENTER' : 'VIEW MORE',
                      showEdit: isCreator && !_isCollisionPopup,
                      onClose: () => setState(() => _selectedEvent = null),
                      onPrimaryAction: () {
                        if (_isCollisionPopup) {
                          ref
                              .read(worldControllerProvider.notifier)
                              .enterEventWorld(_selectedEvent!.id);
                          setState(() => _selectedEvent = null);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) =>
                                  EventDetailsScreen(eventId: _selectedEvent!.id),
                            ),
                          );
                          setState(() => _selectedEvent = null);
                        }
                      },
                      onEditAction: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit coming soon!')),
                        );
                      },
                    ),
                  );
                })(),
              ],

              // 3. My Avatar (Draggable Widget)
              if (worldState.myPosition != null && !worldState.isGpsMode) ...[
                (() {
                  final pos = worldToScreen(
                    worldState.myPosition!.x,
                    worldState.myPosition!.y,
                  );
                  final zoom = worldState.zoom;
                  const baseSize = 60.0;

                  // Check Collision with events
                  if (activeEventId == null) {
                    for (final e in events) {
                      final dist = sqrt(
                        pow(e.x - worldState.myPosition!.x, 2) +
                            pow(e.y - worldState.myPosition!.y, 2),
                      );
                      if (dist < 40 &&
                          (_selectedEvent == null || _isCollisionPopup)) {
                        // Auto trigger enter bubble
                        if (_selectedEvent?.id != e.id) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted)
                              setState(() {
                                _selectedEvent = e;
                                _isCollisionPopup = true;
                              });
                          });
                        }
                      } else if (_selectedEvent?.id == e.id &&
                          _isCollisionPopup &&
                          dist >= 40) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted)
                            setState(() {
                              _selectedEvent = null;
                            });
                        });
                      }
                    }
                  }

                  return AnimatedPositioned(
                    duration: const Duration(
                      milliseconds: 100,
                    ), // Shorter for "ME" to stay responsive
                    curve: Curves.easeOut,
                    left: pos.dx - (baseSize / 2 * zoom),
                    top: pos.dy - (baseSize * 2 * zoom),
                    child: Transform.scale(
                      scale: zoom,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          final zoom = worldState.zoom;
                          final scale = 1.0 / zoom;

                          // Physics Check
                          if (activeEvent?.voxelTheme == 'FOREST') {
                            final nextX =
                                worldState.myPosition!.x +
                                (details.delta.dx * scale);
                            final nextY =
                                worldState.myPosition!.y +
                                (details.delta.dy * scale);

                            if (ForestGenerator.isPositionBlocked(
                              nextX,
                              nextY,
                            )) {
                              return; // Blocked by tree/rock
                            }
                          }

                          ref
                              .read(worldControllerProvider.notifier)
                              .moveMyAvatar(details.delta.dx, details.delta.dy);
                        },
                        onPanEnd: (_) {
                          ref
                              .read(worldControllerProvider.notifier)
                              .forcePositionSync();
                        },
                        child: _AvatarCircle(
                          url: worldState.myPosition!.avatarUrl,
                          isTalking: isTalking,
                          name: 'ME',
                          color: _getProfileColor('me'),
                          isMe: true,
                          size: baseSize,
                        ),
                      ),
                    ),
                  );
                })(),
              ],

              // 3.5 Floating Action Buttons (Snapchat Style) - Empty now, moved contents

              // 4. HUD - Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        // NOTIFICATION ICON (TOP LEFT)
                        Consumer(
                          builder: (context, ref, child) {
                            final unreadCount = ref.watch(notificationServiceProvider.notifier).unreadCount;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: GestureDetector(
                                    onTap: () => showDialog(
                                      context: context,
                                      builder: (c) => const NotificationDialog(),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_rounded,
                                      color: Color(0xFFB452FF),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        unreadCount > 9 ? '9+' : '$unreadCount',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        // FRIENDS ICON (New)
                        Consumer(
                          builder: (context, ref, child) {
                            final requestsCount = ref.watch(friendsProvider).pendingRequests.length;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (c) => const FriendsListScreen(),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.people_alt_rounded,
                                      color: Color(0xFFB452FF),
                                      size: 24,
                                    ),
                                  ),
                                ),
                                if (requestsCount > 0)
                                  Positioned(
                                    top: -2,
                                    right: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        requestsCount > 9 ? '9+' : '$requestsCount',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 12),
                        // NAVIGATION & TITLE
                        if (activeEventId != null && !worldState.isGpsMode)
                          _CircleActionButton(
                            icon: Icons.arrow_back_ios_new,
                            onPressed: () => ref
                                .read(worldControllerProvider.notifier)
                                .exitEventWorld(),
                          ),

                        if (activeEventId != null &&
                            activeEvent != null &&
                            !worldState.isGpsMode) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              activeEvent.title.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),

              if (isOffline)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 10),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'OFFLINE - RECONNECTING',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Room Join Indicator
              if (ref.watch(roomControllerProvider).currentRoom != null)
                Positioned(
                  top: isOffline ? 140 : 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB452FF),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB452FF).withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.meeting_room,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Inside: ${ref.watch(roomControllerProvider).currentRoom!.name}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              ref.read(roomControllerProvider.notifier).leaveRoom();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Left the room'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.exit_to_app,
                                    color: Color(0xFFB452FF),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Exit',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFFB452FF),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 5. Game Session Overlay
              if (ref.watch(gameSessionProvider) != null) ...[
                (() {
                  final gameSession = ref.watch(gameSessionProvider)!;
                  return Stack(
                    children: [
                      // LOBBY STATE
                      if (gameSession.state == 'LOBBY')
                        Positioned.fill(
                          child: Container(
                            color: Colors.black54,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Lobby: ${gameSession.gameType}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '${gameSession.players.length} Players Ready',
                                    ),
                                    const SizedBox(height: 24),
                                    if (gameSession.hostId ==
                                        ref.read(authProvider).user?.id)
                                      ElevatedButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                gameSessionProvider.notifier,
                                              )
                                              .startGame();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('START GAME'),
                                      )
                                    else
                                      const Text(
                                        'Waiting for Host to start...',
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // PLAYING STATE - PROXIMITY TAG
                      if (gameSession.state == 'PLAYING' &&
                          gameSession.gameType == 'PROXIMITY_TAG')
                        Positioned(
                          bottom: 100,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'IMPOSTOR RADAR',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...peers
                                    .where(
                                      (p) =>
                                          p.latitude != 0 && p.longitude != 0,
                                    )
                                    .map((peer) {
                                      final dist = Geolocator.distanceBetween(
                                        worldState.myPosition?.latitude ?? 0,
                                        worldState.myPosition?.longitude ?? 0,
                                        peer.latitude,
                                        peer.longitude,
                                      );
                                      final isClose = dist < 5.0; // 5 meters

                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 4.0,
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              'Target: ${peer.userId.substring(0, 4)}...',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${dist.toStringAsFixed(1)}m',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (isClose)
                                              ElevatedButton(
                                                onPressed: () {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'ELIMINATED ${peer.userId}!',
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.black,
                                                  foregroundColor: Colors.red,
                                                ),
                                                child: const Text('ELIMINATE'),
                                              ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList(),
                                if (peers.every((p) => p.latitude == 0))
                                  const Text(
                                    'No valid GPS signals nearby',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                })(),
              ],

              // 6. Top Right Connection Status
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                right: 20,
                child: Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(30),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.1),
                         blurRadius: 10,
                       )
                     ]
                   ),
                   child: Text(
                     connectionTitle,
                     style: GoogleFonts.outfit(
                       fontWeight: FontWeight.bold,
                       fontSize: 14,
                       color: Colors.black
                     ),
                   ),
                ),
              ),

              // 7. Custom Bottom Navigation with Floating Mic
              Positioned(
                left: 20,
                right: 20,
                bottom: 30,
                child: SizedBox(
                  height: 120, // Increased height area to allow spill over
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // Nav Bar Background
                      Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             // Home
                             Expanded(
                               child: _buildFloatingNavItem(
                                 heroIcon: HeroIcons.home,
                                 isSelected: _selectedNavIndex == 0,
                                 onTap: () => setState(() => _selectedNavIndex = 0),
                               ),
                             ),
                             
                             // Discover (New)
                             Expanded(
                               child: _buildFloatingNavItem(
                                 heroIcon: HeroIcons.globeAlt,
                                 isSelected: _selectedNavIndex == 1,
                                 onTap: () {
                                   setState(() => _selectedNavIndex = 1);
                                   Navigator.push(
                                     context,
                                     MaterialPageRoute(
                                       builder: (context) => const DiscoverScreen(),
                                     ),
                                   ).then((_) {
                                     setState(() => _selectedNavIndex = 0);
                                   });
                                 },
                               ),
                             ),

                             // Space for Mic (Only if Mic is visible)
                             if (!worldState.isGpsMode)
                               const SizedBox(width: 80), 

                             // Messages
                             Expanded(
                               child: Consumer(
                                 builder: (context, ref, _) {
                                   final unreadCount = ref.watch(notificationServiceProvider).where((n) => n.type == 'message' && !n.isRead).length; 
                                   // Note: notificationService state is List<AppNotification>
                                   
                                   return _buildFloatingNavItem(
                                        heroIcon: HeroIcons.chatBubbleLeftRight,
                                        isSelected: _selectedNavIndex == 2,
                                        badgeCount: unreadCount,
                                        onTap: () {
                                          setState(() => _selectedNavIndex = 2);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const MessagesListScreen(),
                                            ),
                                          ).then((_) {
                                            setState(() => _selectedNavIndex = 0);
                                          });
                                        },
                                      );
                                 }
                               ),
                             ),
                             
                             // Profile
                             Expanded(
                               child: _buildFloatingNavItemWithAvatar(
                                 isSelected: _selectedNavIndex == 3,
                                 onTap: () {
                                   setState(() => _selectedNavIndex = 3);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ProfileScreen(),
                                      ),
                                    ).then((_) {
                                      setState(() => _selectedNavIndex = 0);
                                    });
                                 }
                               ),
                             ),
                          ],
                        ),
                      ),
                      
                      // Floating Mic Button - Only in Virtual Mode
                      if (!worldState.isGpsMode)
                        Positioned(
                          bottom: -15, 
                          child: GestureDetector(
                            onTap: () {
                               if (worldState.isMuted && worldState.isManuallyMuted == false) {
                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unmuted. You will talk automatically when someone is near.')));
                               }
                               ref.read(worldControllerProvider.notifier).toggleMute();
                            },
                            child: Container(
                              width: 90, // Bigger than nav bar (which is 60 high)
                              height: 90,
                              decoration: BoxDecoration(
                                color: isTalking ? Colors.grey[300] : Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  )
                                ]
                              ),
                              child: Icon(
                                worldState.isMuted ? Icons.mic_off : Icons.mic,
                                color: isTalking ? Colors.red : Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 4.5. COMPASS INDICATOR (GPS Mode Only)
              if (worldState.isGpsMode && worldState.heading > 0)
                Positioned(
                  top: 100,
                  right: 20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Transform.rotate(
                      angle:
                          (worldState.heading * 3.14159 / 180) -
                          (3.14159 / 2), // Convert to radians
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.red, size: 30),
                          const SizedBox(height: 4),
                          Text(
                            '${worldState.heading.toStringAsFixed(0)}°',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 5. SIDE ACTION BUTTONS (Decluttered)
              Positioned(
                right: 20,
                bottom: 120,
                child: Column(
                  children: [
                    // GPS CENTER (Replaces Alerts in GPS Mode)
                    if (worldState.isGpsMode)
                    _buildSideButton(
                      icon: Icons.my_location,
                      color: Colors.white,
                      iconColor: Colors.black,
                      onTap: () {
                         if (worldState.myPosition != null) {
                           _mapController.move(
                             LatLng(worldState.myPosition!.latitude, worldState.myPosition!.longitude),
                             18.0
                           );
                           setState(() => _userManuallyMovedMap = false);
                         }
                      },
                      label: 'CENTER',
                    ),
                    const SizedBox(height: 16),
                    // GPS SYNC TOGGLE
                    _buildSideButton(
                      icon: worldState.isGpsMode
                          ? Icons.gps_fixed
                          : Icons.gps_off_rounded,
                      color: worldState.isGpsMode
                          ? const Color(0xFFB452FF)
                          : Colors.grey[400]!,
                      onTap: () => ref
                          .read(worldControllerProvider.notifier)
                          .toggleGpsMode(),
                      label: worldState.isGpsMode ? 'GPS ON' : 'GPS OFF',
                    ),
                    const SizedBox(height: 16),
                    // VISIBILITY TOGGLE (Only in GPS mode)
                    if (worldState.isGpsMode)
                      _buildSideButton(
                        icon: worldState.isVisibleOnMap
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: worldState.isVisibleOnMap
                            ? Colors.green
                            : Colors.grey[400]!,
                        onTap: () => ref
                            .read(worldControllerProvider.notifier)
                            .toggleVisibility(),
                        label: worldState.isVisibleOnMap ? 'VISIBLE' : 'HIDDEN',
                      ),
                    if (worldState.isGpsMode) const SizedBox(height: 16),
                    // ACTIVE USERS (Visitors)
                    _buildSideButton(
                      icon: Icons.people_alt_rounded,
                      color: Colors.blue,
                      onTap: () => showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (c) => const ActiveUsersDialog(),
                      ),
                      label: 'VISITORS',
                    ),
                    const SizedBox(height: 16),
                    // PLAY WITH FRIENDS
                    _buildSideButton(
                      icon: Icons.sports_esports_rounded,
                      color: const Color(0xFF000000),
                      onTap: () => _showGameSessionDialog(context, ref),
                      label: 'PLAY',
                    ),
                    const SizedBox(height: 16),
                    // ADD EVENT / ROOM
                    _buildSideButton(
                      icon: worldState.isGpsMode
                          ? Icons.add_location_alt_rounded
                          : Icons.add_home_work_rounded,
                      color: const Color(0xFFFF5E9B),
                      onTap: () {
                        if (worldState.isGpsMode) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const CreateEventScreen(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const CreateRoomScreen(),
                            ),
                          );
                        }
                      },
                      label: worldState.isGpsMode ? 'EVENT' : 'ROOM',
                    ),
                    const SizedBox(height: 16),
                    // RECENTER CAMERA (Only show in virtual mode, hide in GPS mode)
                    if (worldState.myPosition != null && !worldState.isGpsMode)
                      _buildSideButton(
                        icon: Icons.my_location,
                        color: Colors.white,
                        iconColor: Colors.black87,
                        onTap: () {
                          ref
                              .read(worldControllerProvider.notifier)
                              .recenterCamera();
                        },
                        label: 'CENTER',
                      ),
                  ],
                ),
              ),

              // TRACKING ARROWS
              if (worldState.myPosition != null)
                ...worldState.trackedUserIds.map((trackedId) {
                   final target = peers.firstWhere((p) => p.userId == trackedId, orElse: () => AvatarPosition.empty());
                   
                   if (target.userId.isNotEmpty) {
                      double angle = 0;
                      if (worldState.isGpsMode) {
                         // Bearing
                         final bearing = Geolocator.bearingBetween(
                           worldState.myPosition!.latitude, 
                           worldState.myPosition!.longitude, 
                           target.latitude, 
                           target.longitude,
                         );
                         // Adjust by phone heading if valid
                         angle = (bearing - worldState.heading) * (pi / 180); 
                      } else {
                         // Virtual angle
                         angle = atan2(target.y - worldState.myPosition!.y, target.x - worldState.myPosition!.x) + (pi / 2);
                      }
                      
                      Offset centerPos;
                      if (worldState.isGpsMode) {
                         // In GPS mode, assume player is center for the arrow overlay
                         centerPos = Offset(MediaQuery.of(context).size.width / 2, MediaQuery.of(context).size.height / 2);
                      } else {
                         centerPos = worldToScreen(worldState.myPosition!.x, worldState.myPosition!.y);
                      }
                      
                      // Distance text
                      String distText = '';
                      if (worldState.isGpsMode) {
                         final d = Geolocator.distanceBetween(worldState.myPosition!.latitude, worldState.myPosition!.longitude, target.latitude, target.longitude);
                         distText = d > 1000 ? '${(d/1000).toStringAsFixed(1)}km' : '${d.toStringAsFixed(0)}m';
                      } else {
                         final d = sqrt(pow(target.x - worldState.myPosition!.x, 2) + pow(target.y - worldState.myPosition!.y, 2));
                         distText = '${d.toStringAsFixed(0)}m';
                      }

                      return Positioned(
                        left: centerPos.dx - 60,
                        top: centerPos.dy - 60,
                        child: IgnorePointer(
                          child: SizedBox(
                            width: 120, height: 120,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.rotate(
                                  angle: angle, 
                                  child: Container(
                                     width: 120, height: 120,
                                     alignment: Alignment.topCenter,
                                     child: Padding(
                                       padding: const EdgeInsets.only(top: 10),
                                       child: Icon(Icons.navigation_rounded, color: const Color(0xFFB452FF), size: 40),
                                     ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      distText,
                                      style: GoogleFonts.robotoMono(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      );
                   }
                   return const SizedBox.shrink();
                }),

              // Location Status Overlay
              if (isLocationMissing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Color(0xFFB452FF),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'FINDING YOU...',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Please make sure GPS is ON and you have granted permissions.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                ref
                                    .read(worldControllerProvider.notifier)
                                    .toggleGpsMode(); // Toggle off/on to retry
                                ref
                                    .read(worldControllerProvider.notifier)
                                    .toggleGpsMode();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB452FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('RETRY'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildSideButton({
    required IconData icon,
    required Color color,
    Color iconColor = Colors.white,
    required VoidCallback onTap,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Colors.black,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }



  Widget _buildFloatingNavItem({
    required HeroIcons heroIcon,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              HeroIcon(
                heroIcon,
                size: 24,
                color: isSelected ? const Color(0xFFB452FF) : Colors.grey[400],
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFB452FF),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavItemWithAvatar({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final user = ref.watch(authProvider).user;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFB452FF).withOpacity(0.15)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: VoxelAvatar(
            radius: 16,
            avatarUrl: user?.avatarUrl,
            displayName: user?.displayName,
          ),
        ),
      ),
    );
  }

  void _showEventInfoDialog(BuildContext context, VoxelEvent event) {
    final user = ref.read(authProvider).user;
    final isCreator = user?.id == event.creatorId;
    final worldState = ref.read(worldControllerProvider);
    final distance =
        worldState.myPosition != null &&
            event.latitude != 0 &&
            event.longitude != 0
        ? Geolocator.distanceBetween(
            worldState.myPosition!.latitude,
            worldState.myPosition!.longitude,
            event.latitude,
            event.longitude,
          )
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event Title
                    Text(
                      event.title,
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Hot Event Badge
                    if (event.isHot)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'HOT EVENT',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    // Description
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ABOUT THIS EVENT',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey[600],
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            event.description,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Location & Details
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOCATION & DETAILS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.grey[600],
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (distance != null)
                            _buildEventInfoRow(
                              Icons.location_on,
                              'Distance',
                              '${distance.toStringAsFixed(0)} meters away',
                            ),
                          _buildEventInfoRow(
                            Icons.calendar_today,
                            'Start Time',
                            event.startTime.toString().split('.')[0],
                          ),
                          _buildEventInfoRow(
                            Icons.location_pin,
                            'GPS Coordinates',
                            '${event.latitude.toStringAsFixed(6)}, ${event.longitude.toStringAsFixed(6)}',
                          ),
                          _buildEventInfoRow(
                            Icons.people,
                            'Participants',
                            '${event.participantCount} people',
                          ),
                          if (event.isHot)
                            _buildEventInfoRow(
                              Icons.local_fire_department,
                              'Status',
                              'Hot Event (>10 people)',
                            ),
                        ],
                      ),
                    ),
                    if (event.hasTickets) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TICKETING',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Colors.grey[600],
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Entry Ticket',
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '\$${event.ticketPrice.toStringAsFixed(2)}',
                                        style: GoogleFonts.outfit(
                                          color: const Color(0xFFB452FF),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 24,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'TICKET SECURED! 🎟️',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        backgroundColor: const Color(
                                          0xFFB452FF,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF000000),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: Text(
                                    'BUY',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Action Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => EventDetailsScreen(eventId: event.id),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB452FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 8,
                        ),
                        child: Text(
                          'VIEW FULL DETAILS',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    if (isCreator) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Edit coming soon!'),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFFB452FF),
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(
                            'EDIT EVENT',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: const Color(0xFFB452FF),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFB452FF), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUserTrackingDialog(
    BuildContext context,
    WidgetRef ref,
    List<AvatarPosition> peers,
    WorldState worldState,
  ) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TRACK USERS',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Select users to track on map. Leave empty to track all visible users.',
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 300,
                height: 300,
                child: peers.isEmpty
                    ? Center(
                        child: Text(
                          'No users nearby',
                          style: GoogleFonts.outfit(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: peers.length,
                        itemBuilder: (context, index) {
                          final peer = peers[index];
                          final isTracked = worldState.trackedUserIds.contains(
                            peer.userId,
                          );
                          final isVisible = peer.isVisible;

                          if (!isVisible) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isTracked
                                  ? const Color(0xFFB452FF).withOpacity(0.1)
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isTracked
                                    ? const Color(0xFFB452FF)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getProfileColor(peer.userId),
                                child: Text(
                                  peer.username.isNotEmpty
                                      ? peer.username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                peer.username,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${peer.latitude.toStringAsFixed(4)}, ${peer.longitude.toStringAsFixed(4)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                              trailing: Icon(
                                isTracked
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isTracked
                                    ? const Color(0xFFB452FF)
                                    : Colors.grey,
                              ),
                              onTap: () {
                                ref
                                    .read(worldControllerProvider.notifier)
                                    .toggleTrackUser(peer.userId);
                                Navigator.pop(c);
                                _showUserTrackingDialog(
                                  context,
                                  ref,
                                  peers,
                                  ref.read(worldControllerProvider),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      ref
                          .read(worldControllerProvider.notifier)
                          .clearTrackedUsers();
                      Navigator.pop(c);
                    },
                    child: Text(
                      'TRACK ALL',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB452FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'DONE',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGameSessionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECT A GAME',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 250,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                  children: [
                    _buildGameCard(
                      'AMONG US',
                      'https://api.dicebear.com/9.x/icons/png?seed=among',
                      true,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) =>
                                const GameSetupScreen(gameType: 'AMONG US'),
                          ),
                        );
                      },
                    ),
                    _buildGameCard(
                      'TREASURE',
                      'https://api.dicebear.com/9.x/icons/png?seed=treasure',
                      false,
                      () {},
                    ),
                    _buildGameCard(
                      'LOBBY',
                      'https://api.dicebear.com/9.x/icons/png?seed=lobby',
                      false,
                      () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ACTIVE SESSIONS',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, child) {
                  final sessions = ref.watch(availableSessionsProvider);
                  if (sessions.isEmpty)
                    return Text(
                      'No active games found.',
                      style: GoogleFonts.outfit(
                        color: Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                    );

                  return SizedBox(
                    height: 150,
                    child: ListView.builder(
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final s = sessions[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black12),
                          ),
                          child: ListTile(
                            leading: Icon(
                              s.gameType == 'PROXIMITY_TAG'
                                  ? Icons.directions_run
                                  : Icons.map,
                              color: const Color(0xFFB452FF),
                            ),
                            title: Text(
                              s.gameType,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${s.players.length} players • ${s.state}',
                              style: GoogleFonts.outfit(fontSize: 12),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () {
                                ref
                                    .read(gameSessionProvider.notifier)
                                    .joinSession(s.id);
                                Navigator.pop(c);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB452FF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              child: Text(
                                'JOIN',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(
    String title,
    String imagePath,
    bool enabled,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, // Smaller size
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14), // Phone icon style
                  border: Border.all(
                    color: Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                  image: DecorationImage(
                    image: imagePath.startsWith('http')
                        ? NetworkImage(imagePath) as ImageProvider
                        : AssetImage(imagePath),
                    fit: BoxFit.cover,
                  ),
                  boxShadow: [
                    if (enabled)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: !enabled
                    ? Center(
                        child: Text(
                          'SOON',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            shadows: [
                              Shadow(blurRadius: 4, color: Colors.black),
                            ],
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  color: Colors.black.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getProfileColor(String userId) {
    if (userId.startsWith('me')) return const Color(0xFFB452FF);
    final hash = userId.hashCode;
    final colors = [
      const Color(0xFFFF5E9B), // Pink
      const Color(0xFF00D2FF), // Sky Blue
      const Color(0xFF00FF85), // Spring Green
      const Color(0xFFFFCC00), // Gold
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF7D22FF), // Deep Purple
    ];
    return colors[hash.abs() % colors.length];
  }
}

class _AvatarCircle extends StatelessWidget {
  final String url;
  final bool isTalking;
  final String name;
  final Color color;
  final bool isMe;
  final double size;

  const _AvatarCircle({
    required this.url,
    required this.isTalking,
    required this.name,
    required this.color,
    this.isMe = false,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with talking indicator
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isTalking ? Colors.greenAccent : Colors.white,
              width: isTalking ? 4.0 : 3.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
              if (isTalking)
                BoxShadow(
                  color: Colors.greenAccent.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
            ],
          ),
          child: ClipOval(
            child: url.isNotEmpty
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: color,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 32,
                        ),
                      );
                    },
                  )
                : Container(
                    color: color,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        // Username label
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isMe
                ? const Color(0xFFB452FF)
                : Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EventMarker extends StatelessWidget {
  final VoxelEvent event;
  const _EventMarker({required this.event});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFB452FF),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Text(
            event.title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const Icon(Icons.stars, color: Color(0xFFB452FF), size: 40),
      ],
    );
  }
}

class _MapPinMarker extends StatelessWidget {
  final VoxelEvent event;
  const _MapPinMarker({required this.event});

  // Generate pastel color based on event title
  Color _getPastelColor(String title) {
    final hash = title.hashCode;
    final colors = [
      const Color(0xFFFFB3BA), // Pastel Pink
      const Color(0xFFFFDFBA), // Pastel Peach
      const Color(0xFFFFFFBA), // Pastel Yellow
      const Color(0xFFBAFFC9), // Pastel Green
      const Color(0xFFBAE1FF), // Pastel Blue
      const Color(0xFFE0BAFF), // Pastel Purple
      const Color(0xFFFFBAE0), // Pastel Magenta
      const Color(0xFFBAFFF0), // Pastel Cyan
    ];
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final pinColor = _getPastelColor(event.title);
    final firstLetter = event.title.isNotEmpty
        ? event.title[0].toUpperCase()
        : '?';
    final isHot = event.isHot;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Map pin shape
        CustomPaint(
          size: const Size(50, 60),
          painter: _MapPinPainter(color: pinColor),
        ),
        // First letter in circle at top of pin
        Positioned(
          top: 4,
          child: Stack(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: pinColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    firstLetter,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Hot event indicator badge
              if (isHot)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapPinPainter extends CustomPainter {
  final Color color;

  _MapPinPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path();

    // Pin head (rounded top)
    final headRadius = size.width / 2;
    final headCenter = Offset(size.width / 2, headRadius);
    path.addArc(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      -3.14159, // Start from top
      3.14159, // Full semicircle
    );

    // Pin body (trapezoid shape)
    final bodyTop = headRadius * 2;
    final bodyBottom = size.height;
    final bodyTopWidth = size.width * 0.85;
    final bodyBottomWidth = size.width * 0.3;

    path.lineTo((size.width - bodyTopWidth) / 2, bodyTop);
    path.lineTo((size.width - bodyBottomWidth) / 2, bodyBottom);
    path.lineTo((size.width + bodyBottomWidth) / 2, bodyBottom);
    path.lineTo((size.width + bodyTopWidth) / 2, bodyTop);
    path.close();

    canvas.drawPath(path, paint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, borderPaint);

    // Shadow at bottom
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, shadowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DirectionArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Arrow shape (Google Maps style - triangular with rounded edges)
    final path = ui.Path();

    // Arrow head (pointing up)
    final arrowWidth = size.width * 0.4;
    final arrowHeight = size.height * 0.5;

    // Top point
    path.moveTo(center.dx, center.dy - arrowHeight / 2);

    // Right side
    path.lineTo(center.dx + arrowWidth / 2, center.dy + arrowHeight / 4);

    // Bottom right
    path.lineTo(center.dx + arrowWidth / 4, center.dy + arrowHeight / 2);

    // Bottom left
    path.lineTo(center.dx - arrowWidth / 4, center.dy + arrowHeight / 2);

    // Left side
    path.lineTo(center.dx - arrowWidth / 2, center.dy + arrowHeight / 4);

    path.close();

    // Fill with white and shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, shadowPaint);

    // Main arrow fill
    final arrowPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, arrowPaint);

    // Border
    final borderPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WorldInputHandler extends StatefulWidget {
  final Widget child;
  final WidgetRef ref;
  final VoidCallback onZoomStart;
  final Function(double) onZoomUpdate;

  const WorldInputHandler({
    super.key,
    required this.child,
    required this.ref,
    required this.onZoomStart,
    required this.onZoomUpdate,
  });

  @override
  State<WorldInputHandler> createState() => _WorldInputHandlerState();
}

class _WorldInputHandlerState extends State<WorldInputHandler> {
  // We only track panning/zooming. Avatar dragging is handled by Avatar Widgets.

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          final delta = event.scrollDelta.dy;
          // Simple Zoom step
          if (delta > 0) {
            widget.ref.read(worldControllerProvider.notifier).zoomCamera(0.9);
          } else {
            widget.ref.read(worldControllerProvider.notifier).zoomCamera(1.1);
          }
        }
      },
      child: GestureDetector(
        onScaleStart: (details) {
          widget.onZoomStart();
        },
        onScaleUpdate: (details) {
          // Zoom
          if (details.scale != 1.0) {
            widget.onZoomUpdate(details.scale);
          }

          // Pan camera
          widget.ref
              .read(worldControllerProvider.notifier)
              .panCamera(
                details.focalPointDelta.dx,
                details.focalPointDelta.dy,
              );
        },
        child: widget.child,
      ),
    );
  }
}

class VoicePulseDecorator extends StatefulWidget {
  final Color color;
  final double size;
  const VoicePulseDecorator({
    super.key,
    required this.color,
    required this.size,
  });

  @override
  State<VoicePulseDecorator> createState() => _VoicePulseDecoratorState();
}

class _VoicePulseDecoratorState extends State<VoicePulseDecorator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: OverflowBox(
            maxWidth: widget.size * 2,
            maxHeight: widget.size * 2,
            child: Container(
              width: widget.size + (widget.size * 0.4 * _controller.value),
              height: widget.size + (widget.size * 0.4 * _controller.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withOpacity(1 - _controller.value),
                  width: 3.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (widget.color == const Color(0xFFB452FF)
                                ? const Color(
                                    0xFFFF5E9B,
                                  ) // Use pink for purple too
                                : widget.color)
                            .withOpacity(0.6 * (1 - _controller.value)),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _CircleActionButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 24),
      ),
    );
  }
}

class _SquareInfoBubble extends StatelessWidget {
  final String title;
  final String description;
  final String buttonText;
  final bool showEdit;
  final VoidCallback onClose;
  final VoidCallback onPrimaryAction;
  final VoidCallback onEditAction;

  const _SquareInfoBubble({
    required this.title,
    required this.description,
    required this.buttonText,
    required this.showEdit,
    required this.onClose,
    required this.onPrimaryAction,
    required this.onEditAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close, size: 16, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB452FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (showEdit) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onEditAction,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFB452FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(
                  'EDIT',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: const Color(0xFFB452FF),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}


