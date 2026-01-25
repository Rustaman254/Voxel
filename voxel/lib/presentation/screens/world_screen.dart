import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_notifier.dart';
import '../state/world_controller.dart';
import '../state/game_session_provider.dart';
import '../state/peers_provider.dart';
import '../painters/world_painter.dart';
import '../../domain/services/voice_chat_service.dart';

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import '../state/event_notifier.dart';
import 'create_event_screen.dart';
import 'event_details_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'game_setup_screen.dart';
import '../../domain/models/event_model.dart';
import '../../domain/repositories/world_repository.dart';

class WorldScreen extends ConsumerStatefulWidget {
  const WorldScreen({super.key});

  @override
  ConsumerState<WorldScreen> createState() => _WorldScreenState();
}

class _WorldScreenState extends ConsumerState<WorldScreen> {
  // Base zoom for scaling
  double _baseZoom = 1.0;
  
  // Interaction State
  VoxelEvent? _selectedEvent;
  bool _isCollisionPopup = false;
  
  // Voice Visualization - Removed local mic handling

  void _showEventDiscovery(BuildContext context, WidgetRef ref, List<VoxelEvent> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Text(
                    'DISCOVER EVENTS',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB452FF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.explore, color: Color(0xFFB452FF), size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No events nearby yet!',
                          style: GoogleFonts.outfit(color: Colors.grey[500], fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFB452FF), Color(0xFF7D22FF)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(Icons.event_available, color: Colors.white, size: 28),
                          ),
                          title: Text(
                            event.title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              event.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.black38),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            ref.read(worldControllerProvider.notifier).moveCameraTo(event.x, event.y);
                          },
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
  

  @override
  void initState() {
    super.initState();
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
    
    // Ensure proximity logic is active
    ref.watch(proximityLogicProvider);

    final peers = peersAsync.value ?? [];
    
    // Filter peers if in an event world (Simple local filter for now)
    final activeEventId = worldState.activeEventId;
    final activeEvent = activeEventId != null 
        ? events.where((e) => e.id == activeEventId).firstOrNull
        : null;

    final filteredPeers = activeEventId != null
        ? peers // In a real app, the backend would filter this, but we'll show all for now or filter by 'event_id' property if exists
        : peers;
    
    // Proximity logic for UI
    final isNearSomeone = filteredPeers.any((p) {
      final d = Geolocator.distanceBetween(
        worldState.myPosition?.latitude ?? 0, 
        worldState.myPosition?.longitude ?? 0, 
        p.latitude, 
        p.longitude
      );
      return d < 30.0;
    });
    final isTalking = voiceStateAsync.value?.isTalking ?? false; // Now depends on voiceStateProvider
    
    final isCameraAtPlayer = worldState.myPosition != null && 
        (worldState.cameraX - worldState.myPosition!.x).abs() < 200 && 
        (worldState.cameraY - worldState.myPosition!.y).abs() < 200;

    final isOffline = ref.watch(connectionStatusProvider).value == false;
    
    return Scaffold(
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
              WorldInputHandler(
                ref: ref,
                onZoomStart: () {
                   _baseZoom = ref.read(worldControllerProvider).zoom;
                },
                onZoomUpdate: (scale) {
                   ref.read(worldControllerProvider.notifier).zoomCamera(_baseZoom * scale / ref.read(worldControllerProvider).zoom);
                },
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
              
              // 2. Peers & Events
              ...filteredPeers.where((p) => p.userId != worldState.myPosition?.userId).map((peer) {
                final pos = worldToScreen(peer.x, peer.y);
                final zoom = worldState.zoom;
                const baseSize = 60.0;
                
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  left: pos.dx - (baseSize / 2 * zoom),
                  top: pos.dy - (baseSize * 2 * zoom), // Unified offset
                  child: Transform.scale(
                    scale: zoom,
                    alignment: Alignment.bottomCenter,
                    child: _AvatarCircle(
                      url: peer.avatarUrl,
                      isTalking: peer.isTalking,
                      name: peer.username, 
                      color: _getProfileColor(peer.userId),
                      size: baseSize,
                    ),
                  ),
                );
              }),
              
              if (activeEventId == null) ...events.map((e) {
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
              if (_selectedEvent != null) ...[
                (() {
                  final pos = worldToScreen(_selectedEvent!.x, _selectedEvent!.y);
                  final user = ref.read(authProvider).value;
                  final isCreator = user?.id == _selectedEvent!.creatorId;
                  
                  return Positioned(
                    left: pos.dx - 80,
                    top: pos.dy - 180,
                    child: _SquareInfoBubble(
                       title: _isCollisionPopup ? 'ENTER EVENT' : _selectedEvent!.title,
                       description: _isCollisionPopup ? 'You are at the event location!' : _selectedEvent!.description,
                       buttonText: _isCollisionPopup ? 'ENTER' : 'VIEW MORE',
                       showEdit: isCreator && !_isCollisionPopup,
                       onClose: () => setState(() => _selectedEvent = null),
                       onPrimaryAction: () {
                         if (_isCollisionPopup) {
                            ref.read(worldControllerProvider.notifier).enterEventWorld(_selectedEvent!.id);
                            setState(() => _selectedEvent = null);
                         } else {
                            Navigator.push(context, MaterialPageRoute(builder: (c) => EventDetailsScreen(event: _selectedEvent!)));
                            setState(() => _selectedEvent = null);
                         }
                       },
                       onEditAction: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit coming soon!')));
                       },
                    ),
                  );
                })()
              ],

              // 3. My Avatar (Draggable Widget)
              if (worldState.myPosition != null) ...[
                (() {
                  final pos = worldToScreen(worldState.myPosition!.x, worldState.myPosition!.y);
                  final zoom = worldState.zoom;
                  const baseSize = 60.0;
                  
                  // Check Collision with events
                  if (activeEventId == null) {
                    for (final e in events) {
                      final dist = sqrt(pow(e.x - worldState.myPosition!.x, 2) + pow(e.y - worldState.myPosition!.y, 2));
                      if (dist < 40 && (_selectedEvent == null || _isCollisionPopup)) {
                         // Auto trigger enter bubble
                         if (_selectedEvent?.id != e.id) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() { _selectedEvent = e; _isCollisionPopup = true; });
                            });
                         }
                      } else if (_selectedEvent?.id == e.id && _isCollisionPopup && dist >= 40) {
                         WidgetsBinding.instance.addPostFrameCallback((_) {
                           if (mounted) setState(() { _selectedEvent = null; });
                         });
                      }
                    }
                  }

                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 100), // Shorter for "ME" to stay responsive
                    curve: Curves.easeOut,
                    left: pos.dx - (baseSize / 2 * zoom),
                    top: pos.dy - (baseSize * 2 * zoom),
                    child: Transform.scale(
                      scale: zoom,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                           ref.read(worldControllerProvider.notifier).moveMyAvatar(details.delta.dx, details.delta.dy);
                        },
                        onPanEnd: (_) {
                           ref.read(worldControllerProvider.notifier).forcePositionSync();
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
                })()
              ],
              
              // 3.5 Floating Action Buttons (Snapchat Style) - Empty now, moved contents

              // 4. HUD - Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        // DISCOVER BUTTON TOP LEFT
                        _CircleActionButton(
                          icon: Icons.search,
                          onPressed: () => _showEventDiscovery(context, ref, events),
                        ),
                        const Spacer(),
                        // PROFILE SECTION TOP RIGHT
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB452FF), // Primary color
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               const SizedBox(width: 4),
                               CircleAvatar(
                                 radius: 18,
                                 backgroundColor: Colors.white, 
                                 child: Text(
                                    ref.watch(authProvider).value?.displayName.substring(0, 1).toUpperCase() ?? '?',
                                    style: const TextStyle(color: Color(0xFFB452FF), fontWeight: FontWeight.bold), 
                                 ),
                               ),
                               const SizedBox(width: 10),
                               Text(
                                 ref.watch(authProvider).value?.displayName ?? 'User',
                                 style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                               ),
                               const SizedBox(width: 8),
                               IconButton(
                                 constraints: const BoxConstraints(),
                                 padding: const EdgeInsets.all(8),
                                 icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                                 onPressed: () => ref.read(authProvider.notifier).logout(),
                               )
                            ],
                          ),
                        ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, color: Colors.white, size: 14),
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
                                 decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                 child: Column(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Text('Lobby: ${gameSession.gameType}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                     const SizedBox(height: 16),
                                     Text('${gameSession.players.length} Players Ready'),
                                     const SizedBox(height: 24),
                                     if (gameSession.hostId == ref.read(authProvider).value?.id)
                                       ElevatedButton(
                                         onPressed: () {
                                            ref.read(gameSessionProvider.notifier).startGame();
                                         },
                                         style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                         child: const Text('START GAME'),
                                       )
                                     else
                                       const Text('Waiting for Host to start...'),
                                   ],
                                 ),
                               ),
                             ),
                           ),
                         ),

                       // PLAYING STATE - PROXIMITY TAG
                       if (gameSession.state == 'PLAYING' && gameSession.gameType == 'PROXIMITY_TAG')
                        Positioned(
                          bottom: 100,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10)],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'IMPOSTOR RADAR',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                                ),
                                const SizedBox(height: 8),
                                ...peers.where((p) => p.latitude != 0 && p.longitude != 0).map((peer) {
                                   final dist = Geolocator.distanceBetween(
                                      worldState.myPosition?.latitude ?? 0, 
                                      worldState.myPosition?.longitude ?? 0, 
                                      peer.latitude, 
                                      peer.longitude
                                   );
                                   final isClose = dist < 5.0; // 5 meters
                                   
                                   return Padding(
                                     padding: const EdgeInsets.only(bottom: 4.0),
                                     child: Row(
                                       children: [
                                         Text(
                                           'Target: ${peer.userId.substring(0, 4)}...', 
                                           style: const TextStyle(color: Colors.white),
                                         ),
                                         const Spacer(),
                                         Text(
                                           '${dist.toStringAsFixed(1)}m',
                                           style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                         ),
                                         const SizedBox(width: 8),
                                         if (isClose)
                                           ElevatedButton(
                                             onPressed: () {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('ELIMINATED ${peer.userId}!')),
                                                );
                                             },
                                             style: ElevatedButton.styleFrom(
                                               backgroundColor: Colors.black,
                                               foregroundColor: Colors.red,
                                             ),
                                             child: const Text('ELIMINATE'),
                                           )
                                       ],
                                     ),
                                   );
                                }).toList(),
                                if (peers.every((p) => p.latitude == 0))
                                  const Text('No valid GPS signals nearby', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                     ],
                   );
                 })()
              ],

              // 6. HUD - Bottom Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                bottom: isCameraAtPlayer ? 0 : -120,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        // SQUARE MIC BUTTON
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: isTalking 
                                ? const Color(0xFFB452FF) 
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                              if (isTalking)
                                BoxShadow(
                                  color: const Color(0xFFB452FF).withOpacity(0.6), 
                                  blurRadius: 20, 
                                  spreadRadius: 5
                                ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: () {
                                if (worldState.isMuted && worldState.isManuallyMuted == false) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     const SnackBar(content: Text('Unmuted. You will talk automatically when someone is near.'))
                                   );
                                }
                                ref.read(worldControllerProvider.notifier).toggleMute();
                              },
                                child: Icon(
                                  worldState.isMuted ? Icons.mic_off : Icons.mic,
                                  color: isTalking ? Colors.white : (worldState.isMuted ? Colors.red : Colors.black54), 
                                  size: 28,
                                ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                 color: Colors.white.withOpacity(0.7),
                                 borderRadius: BorderRadius.circular(50),
                                 border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                                 boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isNearSomeone ? 'Proximity Voice' : 'Not near anyone',
                                          style: GoogleFonts.outfit(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (isTalking && !isNearSomeone)
                                          Text(
                                            'No one can hear you', 
                                            style: GoogleFonts.outfit(color: Colors.orange[800], fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
                    // GPS SYNC TOGGLE
                    _buildSideButton(
                      icon: worldState.isGpsMode ? Icons.gps_fixed : Icons.gps_off_rounded,
                      color: worldState.isGpsMode ? const Color(0xFFB452FF) : Colors.grey[400]!,
                      onTap: () => ref.read(worldControllerProvider.notifier).toggleGpsMode(),
                      label: worldState.isGpsMode ? 'GPS ON' : 'GPS OFF',
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
                    // ADD EVENT
                    _buildSideButton(
                      icon: Icons.add_location_alt_rounded,
                      color: const Color(0xFFFF5E9B),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CreateEventScreen())),
                      label: 'EVENT',
                    ),
                    const SizedBox(height: 16),
                    // RECENTER CAMERA (Bottom of Create Event)
                    if (worldState.myPosition != null && 
                        ((worldState.cameraX - worldState.myPosition!.x).abs() > 100 || 
                         (worldState.cameraY - worldState.myPosition!.y).abs() > 100))
                      _buildSideButton(
                        icon: Icons.my_location,
                        color: Colors.white,
                        iconColor: Colors.black87,
                        onTap: () => ref.read(worldControllerProvider.notifier).recenterCamera(),
                        label: 'CENTER',
                      ),
                  ],
                ),
              ),
            ],
          );
        }
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
                )
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

  void _showGameSessionDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (c) => Dialog(
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
            Text('SELECT A GAME', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
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
                  _buildGameCard('AMONG US', 'https://api.dicebear.com/9.x/icons/png?seed=among', true, () {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => const GameSetupScreen(gameType: 'AMONG US')));
                  }),
                  _buildGameCard('TREASURE', 'https://api.dicebear.com/9.x/icons/png?seed=treasure', false, () {}),
                  _buildGameCard('LOBBY', 'https://api.dicebear.com/9.x/icons/png?seed=lobby', false, () {}),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('ACTIVE SESSIONS', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, child) {
                  final sessions = ref.watch(availableSessionsProvider);
                  if (sessions.isEmpty) return Text('No active games found.', style: GoogleFonts.outfit(color: Colors.black54, fontStyle: FontStyle.italic));
                  
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
                             leading: Icon(s.gameType == 'PROXIMITY_TAG' ? Icons.directions_run : Icons.map, color: const Color(0xFFB452FF)),
                             title: Text(s.gameType, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                             subtitle: Text('${s.players.length} players • ${s.state}', style: GoogleFonts.outfit(fontSize: 12)),
                             trailing: ElevatedButton(
                                onPressed: () {
                                  ref.read(gameSessionProvider.notifier).joinSession(s.id);
                                  Navigator.pop(c);
                                },
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: const Color(0xFFB452FF),
                                   foregroundColor: Colors.white,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                   padding: const EdgeInsets.symmetric(horizontal: 16),
                                 ),
                                 child: Text('JOIN', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                             ),
                           ),
                         );
                      },
                    ),
                  );
              }
            )
          ],
        ),
      ),
    ));
  }

  Widget _buildGameCard(String title, String imagePath, bool enabled, VoidCallback onTap) {
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
                  border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
                  image: DecorationImage(
                    image: imagePath.startsWith('http') ? NetworkImage(imagePath) as ImageProvider : AssetImage(imagePath), 
                    fit: BoxFit.cover
                  ),
                  boxShadow: [
                    if (enabled) 
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                  ],
                ),
                child: !enabled ? Center(child: Text('SOON', style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 10, shadows: [Shadow(blurRadius: 4, color: Colors.black)]))) : null,
              ),
              const SizedBox(height: 4),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.black.withOpacity(0.7)), textAlign: TextAlign.center, maxLines: 1),
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
  final bool isMe;
  final Color color;
  final double size;
 
  const _AvatarCircle({
    required this.url,
    required this.isTalking,
    required this.name,
    required this.color,
    this.isMe = false,
    this.size = 60.0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFB452FF) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isMe ? Colors.white : color.withOpacity(0.5), width: isMe ? 2 : 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTalking && !isMe) Icon(Icons.mic, size: 10, color: color),
              if (isTalking && isMe) const Icon(Icons.mic, size: 10, color: Colors.white),
              const SizedBox(width: 2),
              Text(
                name, 
                style: GoogleFonts.outfit(
                  fontSize: 11, 
                  fontWeight: FontWeight.w900, 
                  color: isMe ? Colors.white : color
                )
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            if (isTalking) VoicePulseDecorator(color: color, size: size),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3), 
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: CircleAvatar(
                backgroundImage: url.isNotEmpty 
                    ? NetworkImage(url) 
                    : null,
                backgroundColor: Colors.grey[200],
                child: url.isEmpty 
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: size * 0.3, color: color),
                      )
                    : null,
              ),
            ),
            if (isTalking)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.mic, size: 10, color: Colors.white),
                ),
              ),
          ],
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
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
          ),
        ),
        const Icon(Icons.stars, color: Color(0xFFB452FF), size: 40),
      ],
    );
  }
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
          widget.ref.read(worldControllerProvider.notifier).panCamera(
            details.focalPointDelta.dx, 
            details.focalPointDelta.dy
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
  const VoicePulseDecorator({super.key, required this.color, required this.size});

  @override
  State<VoicePulseDecorator> createState() => _VoicePulseDecoratorState();
}

class _VoicePulseDecoratorState extends State<VoicePulseDecorator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
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
                    color: (widget.color == const Color(0xFFB452FF) 
                        ? const Color(0xFFFF5E9B) // Use pink for purple too
                        : widget.color).withOpacity(0.6 * (1 - _controller.value)),
                    blurRadius: 20,
                    spreadRadius: 4,
                  )
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 8),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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