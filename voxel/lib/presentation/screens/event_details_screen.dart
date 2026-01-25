import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/models/event_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_notifier.dart';
import '../state/world_controller.dart';

class EventDetailsScreen extends ConsumerWidget {
  final VoxelEvent event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).value;
    final isCreator = user?.id == event.creatorId;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB452FF),
        elevation: 0,
        centerTitle: true,
        title: Text(
          'EVENT DETAILS',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.5,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                event.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSnapCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('ABOUT THIS EVENT'),
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
            const SizedBox(height: 24),
            _buildSnapCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('WHERE & WHEN'),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.calendar_today_rounded, 'Start Time', event.startTime.toString().split('.')[0]),
                  _buildDetailRow(Icons.location_on_rounded, 'Voxel Coords', '${event.x.toStringAsFixed(1)}, ${event.y.toStringAsFixed(1)}'),
                  _buildDetailRow(Icons.person_pin_circle_rounded, 'Creator', event.creatorId),
                  _buildDetailRow(Icons.palette_rounded, 'Theme Style', event.voxelTheme),
                ],
              ),
            ),
            if (event.hasTickets) ...[
              const SizedBox(height: 24),
              _buildSnapCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('TICKETING'),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Entry Ticket', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18)),
                              Text('\$${event.ticketPrice.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: const Color(0xFFB452FF), fontWeight: FontWeight.w900, fontSize: 24)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showPurchaseDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF000000),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            elevation: 0,
                          ),
                          child: Text('BUY', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(worldControllerProvider.notifier).enterEventWorld(event.id);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB452FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                        elevation: 8,
                        shadowColor: const Color(0xFFB452FF).withOpacity(0.4),
                      ),
                      child: Text(
                        'ENTER WORLD 🚀',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2),
                      ),
                    ),
                  ),
                ),
                if (isCreator) ...[
                  const SizedBox(width: 16),
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.black),
                      onPressed: () {
                        // TODO: Implement edit functionality or navigate to edit screen
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edit session coming soon!'))
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.grey[600],
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFFF5E9B), size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w900, letterSpacing: 1.0)),
                Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Text('GET YOUR TICKET', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        content: Text('Ready to vibe at ${event.title}?', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('NOT YET', style: GoogleFonts.outfit(color: Colors.grey[600], fontWeight: FontWeight.w900)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('TICKET SECURED! 🎟️', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                  backgroundColor: const Color(0xFFB452FF),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB452FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
            child: Text('LET\'S GO', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
