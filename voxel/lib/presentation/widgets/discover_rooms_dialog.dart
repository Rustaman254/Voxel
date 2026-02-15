import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/room.dart';
import '../state/room_controller.dart';
import '../state/world_controller.dart';
import '../screens/room_details_screen.dart';
import 'package:geolocator/geolocator.dart';

class DiscoverRoomsDialog extends ConsumerStatefulWidget {
  const DiscoverRoomsDialog({super.key});

  @override
  ConsumerState<DiscoverRoomsDialog> createState() => _DiscoverRoomsDialogState();
}

class _DiscoverRoomsDialogState extends ConsumerState<DiscoverRoomsDialog> {
  bool _showPrivate = false;

  @override
  void initState() {
    super.initState();
    // Load rooms when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomControllerProvider.notifier).loadRooms();
    });
  }

  String _formatCoordinates(Room room, bool isGpsMode) {
    if (isGpsMode && room.latitude != 0 && room.longitude != 0) {
      return '${room.latitude.toStringAsFixed(4)}, ${room.longitude.toStringAsFixed(4)}';
    } else {
      return 'X: ${room.x.toStringAsFixed(0)}, Y: ${room.y.toStringAsFixed(0)}';
    }
  }

  double? _calculateDistance(Room room, WorldState worldState) {
    if (worldState.isGpsMode && 
        worldState.myPosition != null &&
        room.latitude != 0 && 
        room.longitude != 0 &&
        worldState.myPosition!.latitude != 0) {
      return Geolocator.distanceBetween(
        worldState.myPosition!.latitude,
        worldState.myPosition!.longitude,
        room.latitude,
        room.longitude,
      );
    }
    return null;
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m away';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km away';
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomControllerProvider);
    final worldState = ref.watch(worldControllerProvider);
    final isGpsMode = worldState.isGpsMode;

    // Filter rooms based on privacy setting
    final filteredRooms = roomState.rooms.where((room) {
      if (_showPrivate) return true;
      return !room.isPrivate;
    }).toList();

    // Sort by distance if in GPS mode
    if (isGpsMode && worldState.myPosition != null) {
      filteredRooms.sort((a, b) {
        final distA = _calculateDistance(a, worldState) ?? double.infinity;
        final distB = _calculateDistance(b, worldState) ?? double.infinity;
        return distA.compareTo(distB);
      });
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFB452FF),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.explore, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'DISCOVER ROOMS',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Filter Toggle
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Show Private Rooms',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Switch(
                    value: _showPrivate,
                    onChanged: (val) => setState(() => _showPrivate = val),
                    activeColor: const Color(0xFFB452FF),
                  ),
                ],
              ),
            ),

            // Loading or Empty State
            if (roomState.isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFB452FF)),
                ),
              )
            else if (filteredRooms.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No rooms available',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create one to get started!',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              // Rooms List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredRooms.length,
                  itemBuilder: (context, index) {
                    final room = filteredRooms[index];
                    final distance = _calculateDistance(room, worldState);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: room.isPrivate 
                              ? Colors.orange.withOpacity(0.3)
                              : const Color(0xFFB452FF).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Room Name and Privacy
                            Row(
                              children: [
                                Icon(
                                  room.isPrivate ? Icons.lock : Icons.public,
                                  size: 20,
                                  color: room.isPrivate ? Colors.orange : const Color(0xFFB452FF),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    room.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.people, size: 14, color: Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${room.members.length}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            if (room.description.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                room.description,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Coordinates and Distance
                            Row(
                              children: [
                                Icon(
                                  isGpsMode ? Icons.location_on : Icons.map,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    _formatCoordinates(room, isGpsMode),
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                                if (distance != null)
                                  Text(
                                    _formatDistance(distance),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFFB452FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Action Buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      // Center map on room coordinates
                                      if (isGpsMode && room.latitude != 0 && room.longitude != 0) {
                                        ref.read(roomControllerProvider.notifier).centerMapOnRoom(room);
                                      } else {
                                        ref.read(worldControllerProvider.notifier).moveCameraTo(room.x, room.y);
                                      }
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.my_location, size: 16),
                                    label: Text(
                                      'View on Map',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFB452FF),
                                      side: const BorderSide(color: Color(0xFFB452FF)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await ref.read(roomControllerProvider.notifier).joinRoom(room.id);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Joined ${room.name}'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.login, size: 16),
                                    label: Text(
                                      'Join',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFB452FF),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
