import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../state/peers_provider.dart';
import '../state/world_controller.dart';
import 'dart:math';

class ActiveUsersDialog extends ConsumerWidget {
  const ActiveUsersDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peers = ref.watch(peersProvider);
    final worldState = ref.watch(worldControllerProvider);
    final isGpsMode = worldState.isGpsMode;
    
    // Sort peers by distance if in GPS mode
    final sortedPeers = [...peers];
    if (isGpsMode && worldState.myPosition != null) {
      sortedPeers.sort((a, b) {
        final distA = _calculateDistance(
          worldState.myPosition!.latitude,
          worldState.myPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = _calculateDistance(
          worldState.myPosition!.latitude,
          worldState.myPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });
    } else {
      // Sort by virtual distance
      sortedPeers.sort((a, b) {
        final myX = worldState.myPosition?.x ?? 0.0;
        final myY = worldState.myPosition?.y ?? 0.0;
        
        final distA = _calculateVirtualDistance(
          myX,
          myY,
          a.x,
          a.y,
        );
        final distB = _calculateVirtualDistance(
          myX,
          myY,
          b.x,
          b.y,
        );
        return distA.compareTo(distB);
      });
    }
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 400),
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
              decoration: const BoxDecoration(
                color: Color(0xFFB452FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ACTIVE USERS',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  Text(
                    '${peers.length}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Users List
            Expanded(
              child: peers.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            'No active users nearby',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: sortedPeers.length,
                      itemBuilder: (context, index) {
                        final peer = sortedPeers[index];
                        final isTracking = worldState.trackedUserIds.contains(peer.userId);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isTracking ? const Color(0xFFB452FF).withOpacity(0.1) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isTracking ? const Color(0xFFB452FF) : Colors.grey[200]!,
                              width: isTracking ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.grey[200],
                                  backgroundImage: NetworkImage(
                                    'https://api.dicebear.com/9.x/adventurer/png?seed=${peer.userId}',
                                  ),
                                ),
                                if (isTracking)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB452FF),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                      child: const Icon(
                                        Icons.navigation,
                                        color: Colors.white,
                                        size: 8,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              peer.username.isNotEmpty ? peer.username : 'User ${peer.userId.substring(0, 6)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              _formatDistance(peer, isGpsMode, worldState),
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                isTracking ? Icons.navigation : Icons.navigation_outlined,
                                color: isTracking ? const Color(0xFFB452FF) : Colors.grey[600],
                              ),
                              onPressed: () {
                                if (isTracking) {
                                  ref.read(worldControllerProvider.notifier).toggleTrackUser(peer.userId);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
            
            // Footer Info
            if (worldState.trackedUserIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFB452FF).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Color(0xFFB452FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'An arrow will point to the tracked user',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFFB452FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  String _formatDistance(peer, bool isGpsMode, WorldState worldState) {
    if (isGpsMode && peer.latitude != 0 && peer.longitude != 0) {
      if (worldState.myPosition != null) {
        final distance = _calculateDistance(
          worldState.myPosition!.latitude,
          worldState.myPosition!.longitude,
          peer.latitude,
          peer.longitude,
        );
        if (distance < 1) {
          return '${(distance * 1000).toStringAsFixed(0)} m away';
        }
        return '${distance.toStringAsFixed(2)} km away';
      }
      return '${peer.latitude.toStringAsFixed(4)}, ${peer.longitude.toStringAsFixed(4)}';
    } else {
      final myX = worldState.myPosition?.x ?? 0.0;
      final myY = worldState.myPosition?.y ?? 0.0;
      
      final distance = _calculateVirtualDistance(
        myX,
        myY,
        peer.x,
        peer.y,
      );
      return 'Virtual: ${distance.toStringAsFixed(0)} units away';
    }
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // km
  }
  
  double _calculateVirtualDistance(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }
}
