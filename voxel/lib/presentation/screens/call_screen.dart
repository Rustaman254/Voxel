import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CallScreen extends StatefulWidget {
  final String peerName;
  final String peerAvatar;

  const CallScreen({super.key, required this.peerName, required this.peerAvatar});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E2E2E),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundImage: widget.peerAvatar.isNotEmpty ? NetworkImage(widget.peerAvatar) : null,
              backgroundColor: Colors.grey[800],
              child: widget.peerAvatar.isEmpty ? const Icon(Icons.person, size: 60) : null,
            ),
            const SizedBox(height: 20),
            Text(
              widget.peerName,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Calling...',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(Icons.mic_off, Colors.white, Colors.white24, () {}),
                _buildControlButton(Icons.call_end, Colors.white, Colors.red, () => Navigator.pop(context), size: 72),
                _buildControlButton(Icons.volume_up, Colors.white, Colors.white24, () {}),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, Color iconColor, Color bgColor, VoidCallback onTap, {double size = 56}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: size * 0.5),
      ),
    );
  }
}
