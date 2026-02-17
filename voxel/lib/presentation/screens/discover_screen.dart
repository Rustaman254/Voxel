import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/room.dart';
import '../state/room_controller.dart';
import '../state/world_controller.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  bool _showPrivate = false;

  @override
  void initState() {
    super.initState();
    // Load rooms when screen opens
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // Back button handled by navigation logic in World Screen if integrated, 
            // or we add a back button if pushed. 
            // Assuming this is a main tab, no back button needed unless requested.
            // But if it's pushed, we need one. The implementation plan said "full page".
            // Let's add a back button for safety if canPop.
             if (Navigator.canPop(context))
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            Text(
              'Discover',
              style: GoogleFonts.outfit(
                color: Colors.black,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        actions: [
          // Filter Toggle
          Row(
            children: [
              Text(
                'Private',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              Switch(
                value: _showPrivate,
                onChanged: (val) => setState(() => _showPrivate = val),
                 activeColor: const Color(0xFFB452FF),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
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
                    Icon(Icons.travel_explore, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No rooms found',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try changing filters or create a room!',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: filteredRooms.length,
                itemBuilder: (context, index) {
                  final room = filteredRooms[index];
                  final distance = _calculateDistance(room, worldState);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: room.isPrivate 
                            ? Colors.orange.withOpacity(0.3)
                            : const Color(0xFFB452FF).withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                         BoxShadow(
                           color: Colors.black.withOpacity(0.03),
                           blurRadius: 10,
                           offset: const Offset(0, 4),
                         )
                      ]
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Room Name and Privacy
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: room.isPrivate ? Colors.orange.withOpacity(0.1) : const Color(0xFFB452FF).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  room.isPrivate ? Icons.lock : Icons.public,
                                  size: 20,
                                  color: room.isPrivate ? Colors.orange : const Color(0xFFB452FF),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      room.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
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
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
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
                            const SizedBox(height: 12),
                            Text(
                              room.description,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    if (isGpsMode && room.latitude != 0 && room.longitude != 0) {
                                      ref.read(roomControllerProvider.notifier).centerMapOnRoom(room);
                                    } else {
                                      ref.read(worldControllerProvider.notifier).moveCameraTo(room.x, room.y);
                                    }
                                    Navigator.pop(context);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black87,
                                    side: BorderSide(color: Colors.grey[300]!),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'View Map',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
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
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB452FF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Join Room',
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
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
        ],
      ),
    );
  }
}
