import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/connection_tracker_provider.dart';

class ConnectionCounterWidget extends ConsumerWidget {
  final bool showDetails;
  
  const ConnectionCounterWidget({
    super.key,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracker = ref.watch(connectionTrackerProvider);
    final totalConnections = tracker.totalConnections;
    
    if (showDetails) {
      return _buildDetailedView(context, tracker);
    }
    
    return _buildCompactView(context, totalConnections);
  }
  
  Widget _buildCompactView(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFB452FF).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFB452FF).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: count > 0 ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.people_rounded,
            color: const Color(0xFFB452FF),
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: GoogleFonts.outfit(
              color: const Color(0xFFB452FF),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailedView(BuildContext context, ConnectionTracker tracker) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.people_rounded,
                color: Color(0xFFB452FF),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Connections',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFB452FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tracker.totalConnections}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildConnectionRow(
            'Friends',
            tracker.friendsCount,
            Icons.person_rounded,
            Colors.blue,
          ),
          const SizedBox(height: 8),
          _buildConnectionRow(
            'Room Members',
            tracker.roomMembersCount,
            Icons.meeting_room_rounded,
            Colors.orange,
          ),
          const SizedBox(height: 8),
          _buildConnectionRow(
            'Event Participants',
            tracker.eventParticipantsCount,
            Icons.event_rounded,
            Colors.green,
          ),
        ],
      ),
    );
  }
  
  Widget _buildConnectionRow(String label, int count, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          '$count',
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
