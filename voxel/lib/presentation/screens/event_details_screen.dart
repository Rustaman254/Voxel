import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/event_model.dart';
import '../state/event_notifier.dart';
import '../state/auth_notifier.dart';

class EventDetailsScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventProvider);
    final user = ref.watch(authProvider).user;
    
    final event = events.firstWhere(
      (e) => e.id == eventId,
      orElse: () => VoxelEvent(
        id: '', 
        title: 'Not Found', 
        description: '', 
        x: 0, y: 0, 
        creatorId: '',
        startTime: DateTime.now(),
      ),
    );

    if (event.id.isEmpty) {
      return Scaffold(body: Center(child: Text('Event not found', style: GoogleFonts.outfit())));
    }

    final isCreator = event.creatorId == user?.id;
    final isAttending = event.attendeeIds.contains(user?.id);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFFB452FF),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                event.title.toUpperCase(),
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFB452FF), const Color(0xFFFF5E9B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    event.voxelTheme == 'SPACE' ? '🚀' : (event.voxelTheme == 'FOREST' ? '🌲' : '🏙️'),
                    style: const TextStyle(fontSize: 80),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildInfoTag(
                        event.isPrivate ? 'PRIVATE' : 'PUBLIC',
                        event.isPrivate ? const Color(0xFFB452FF) : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      _buildInfoTag(
                        '${event.attendeeIds.length} ATTENDING',
                        Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'DETAILS',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Colors.grey,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    event.description,
                    style: GoogleFonts.outfit(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 32),
                  _buildIconInfo(Icons.calendar_today, 'Starts At', event.startTime.toString().split('.')[0]),
                  _buildIconInfo(Icons.attach_money, 'Price', event.hasTickets ? '\$${event.ticketPrice}' : 'FREE'),
                  const SizedBox(height: 32),
                  Text(
                    'ATTENDEES',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Colors.grey,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (event.attendeeIds.isEmpty)
                    Text('No one yet. Be the first!', style: GoogleFonts.outfit(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: event.attendeeIds.map((id) => _buildAttendeeCircle(id)).toList(),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (isAttending) {
                    ref.read(eventProvider.notifier).leaveEvent(event.id);
                  } else {
                    ref.read(eventProvider.notifier).joinEvent(event.id);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAttending ? Colors.redAccent : const Color(0xFF000000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(
                  isAttending ? 'LEAVE EVENT' : 'JOIN EVENT',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
              ),
            ),
            if (isCreator) ...[
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  ref.read(eventProvider.notifier).removeEvent(event.id);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                padding: const EdgeInsets.all(16),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildIconInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFB452FF)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11)),
              Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendeeCircle(String userId) {
    // Ideally fetch user avatar, for now placeholder
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: const Center(child: Icon(Icons.person, size: 20, color: Colors.white)),
    );
  }
}
