import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../state/peers_provider.dart';
import '../state/world_controller.dart';
import '../state/auth_notifier.dart';
import 'voxel_avatar.dart';
import 'dart:math';

class ActiveUsersDialog extends ConsumerWidget {
  const ActiveUsersDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(peersStreamProvider);
    final worldState = ref.watch(worldControllerProvider);
    final currentUser = ref.watch(authProvider).user;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Visitors',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Content
          Flexible(
            child: peersAsync.when(
              data: (peers) {
                // Filter out current user
                final otherPeers = peers
                    .where((p) => p.userId != currentUser?.id)
                    .toList();

                if (otherPeers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No visitors',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                         Text(
                          'There are no visitors nearby.',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 24,
                    alignment: WrapAlignment.start,
                    children: otherPeers.map((peer) {
                      final distance = _formatDistance(peer, worldState.isGpsMode, worldState);
                      return _buildUserAvatar(
                        peer.username.isNotEmpty ? peer.username : 'User',
                        peer.avatarUrl,
                        peer.isVisible,
                        distance,
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFB452FF),
                  ),
                ),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load visitors',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String username, String avatarUrl, bool isOnline, String distance) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isOnline ? const Color(0xFF00D856) : Colors.grey[300]!,
                    width: 3,
                  ),
                ),
                child: VoxelAvatar(
                  radius: 32,
                  avatarUrl: avatarUrl,
                  displayName: username,
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D856),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            username,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (distance.isNotEmpty)
            Text(
              distance,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }

  String _formatDistance(peer, bool isGpsMode, WorldState worldState) {
    if (isGpsMode) {
      // GPS mode: calculate real-world distance
      if (worldState.myPosition != null &&
          peer.latitude != 0 &&
          peer.longitude != 0) {
        final distance = _calculateDistance(
          worldState.myPosition!.latitude,
          worldState.myPosition!.longitude,
          peer.latitude,
          peer.longitude,
        );
        if (distance < 1000) {
          return '${distance.toStringAsFixed(0)}m';
        } else {
          return '${(distance / 1000).toStringAsFixed(1)}km';
        }
      }
    } else {
      // Virtual mode: calculate virtual distance
      if (worldState.myPosition != null) {
        final distance = _calculateVirtualDistance(
          worldState.myPosition!.x,
          worldState.myPosition!.y,
          peer.x,
          peer.y,
        );
        return '${distance.toStringAsFixed(0)}u';
      }
    }
    return '';
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  double _calculateVirtualDistance(double x1, double y1, double x2, double y2) {
    return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
  }
}
