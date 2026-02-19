import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/voice_chat/voice_chat_bloc.dart';
import '../state/peers_provider.dart';

class VoiceChatWidget extends ConsumerWidget {
  const VoiceChatWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocBuilder<VoiceChatBloc, VoiceChatBlocState>(
      builder: (context, state) {
        if (state is VoiceChatInitial || state is VoiceChatDisconnected) {
          return const SizedBox.shrink();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildContent(context, ref, state),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, VoiceChatBlocState state) {
    if (state is VoiceChatConnecting) {
      return _VoiceConnectingCard(channelId: state.channelId);
    }
    if (state is VoiceChatConnected) {
      return _VoiceConnectedCard(state: state, ref: ref);
    }
    if (state is VoiceChatError) {
      return _VoiceErrorCard(message: state.message);
    }
    return const SizedBox.shrink();
  }
}

// --- Connecting State ---
class _VoiceConnectingCard extends StatefulWidget {
  final String? channelId;
  const _VoiceConnectingCard({this.channelId});

  @override
  State<_VoiceConnectingCard> createState() => _VoiceConnectingCardState();
}

class _VoiceConnectingCardState extends State<_VoiceConnectingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A1A2E).withOpacity(0.95),
            const Color(0xFF16213E).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB452FF).withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB452FF).withOpacity(0.2 + _pulseController.value * 0.2),
                  border: Border.all(
                    color: const Color(0xFFB452FF).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.mic, color: Color(0xFFB452FF), size: 20),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Connecting...',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.channelId != null)
                  Text(
                    widget.channelId!,
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<VoiceChatBloc>().add(const LeaveVoiceChannel());
            },
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Connected State ---
class _VoiceConnectedCard extends StatefulWidget {
  final VoiceChatConnected state;
  final WidgetRef ref;
  const _VoiceConnectedCard({required this.state, required this.ref});

  @override
  State<_VoiceConnectedCard> createState() => _VoiceConnectedCardState();
}

class _VoiceConnectedCardState extends State<_VoiceConnectedCard>
    with TickerProviderStateMixin {
  late AnimationController _speakingController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _speakingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    if (widget.state.isTalking) {
      _speakingController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _VoiceConnectedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isTalking && !_speakingController.isAnimating) {
      _speakingController.repeat(reverse: true);
    } else if (!widget.state.isTalking && _speakingController.isAnimating) {
      _speakingController.stop();
      _speakingController.value = 0;
    }
  }

  @override
  void dispose() {
    _speakingController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectedCount = widget.state.connectedUserIds.length;
    final isMuted = widget.state.isMuted;
    final isTalking = widget.state.isTalking;
    
    // Watch peers to get their speaking status
    final peersAsync = widget.ref.watch(peersStreamProvider);
    final peers = peersAsync.value ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1A2E).withOpacity(0.95),
            const Color(0xFF16213E).withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isTalking
              ? const Color(0xFFB452FF).withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
          width: isTalking ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isTalking
                ? const Color(0xFFB452FF).withOpacity(0.2)
                : Colors.black.withOpacity(0.3),
            blurRadius: isTalking ? 24 : 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row: status + participant count
          Row(
            children: [
              // Speaking waveform or static mic
              if (isTalking) _buildWaveform() else _buildStaticMicIcon(),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTalking ? 'Speaking' : (isMuted ? 'Muted' : 'Voice Connected'),
                      style: GoogleFonts.outfit(
                        color: isTalking ? const Color(0xFFB452FF) : Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$connectedCount ${connectedCount == 1 ? 'user' : 'users'} connected',
                      style: GoogleFonts.outfit(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // User count badge
              if (connectedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB452FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people, color: Color(0xFFB452FF), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '$connectedCount',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFB452FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          // Participant avatars row
          if (connectedCount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: widget.state.connectedUserIds.length,
                itemBuilder: (context, index) {
                  final userId = widget.state.connectedUserIds.elementAt(index);
                  // Find peer in list to get their speaking status
                  final peer = peers.where((p) => p.userId == userId).firstOrNull;
                  
                  return _ParticipantAvatar(
                    userId: userId,
                    userName: peer?.username ?? '?',
                    avatarUrl: peer?.avatarUrl ?? '',
                    isSpeaking: peer?.isTalking ?? false,
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mute button
              _ActionButton(
                icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: isMuted ? 'Unmute' : 'Mute',
                color: isMuted ? Colors.redAccent : const Color(0xFFB452FF),
                onTap: () {
                  context.read<VoiceChatBloc>().add(ToggleMute(muted: !isMuted));
                },
              ),
              const SizedBox(width: 24),
              // Leave button
              _ActionButton(
                icon: Icons.call_end_rounded,
                label: 'Leave',
                color: Colors.redAccent,
                onTap: () {
                  context.read<VoiceChatBloc>().add(const LeaveVoiceChannel());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFB452FF).withOpacity(0.15),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulsing ring
              AnimatedBuilder(
                animation: _speakingController,
                builder: (context, _) {
                  return Container(
                    width: 36 + _speakingController.value * 8,
                    height: 36 + _speakingController.value * 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFB452FF).withOpacity(0.4 - _speakingController.value * 0.3),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              const Icon(Icons.mic, color: Color(0xFFB452FF), size: 18),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaticMicIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.state.isMuted
            ? Colors.redAccent.withOpacity(0.15)
            : Colors.white.withOpacity(0.08),
      ),
      child: Icon(
        widget.state.isMuted ? Icons.mic_off : Icons.mic,
        color: widget.state.isMuted ? Colors.redAccent : Colors.white54,
        size: 18,
      ),
    );
  }
}

// --- Participant Avatar ---
class _ParticipantAvatar extends StatelessWidget {
  final String userId;
  final String userName;
  final String avatarUrl;
  final bool isSpeaking;

  const _ParticipantAvatar({
    required this.userId, 
    required this.userName, 
    required this.avatarUrl,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Speaking ring animation
          if (isSpeaking)
            _SpeakingRingAnimation(color: const Color(0xFFB452FF)),
            
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSpeaking ? const Color(0xFFB452FF) : Colors.white.withOpacity(0.1),
                width: isSpeaking ? 2 : 1,
              ),
              color: Colors.white.withOpacity(0.08),
            ),
            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
          if (isSpeaking)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFFB452FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1A1A2E), width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SpeakingRingAnimation extends StatefulWidget {
  final Color color;
  const _SpeakingRingAnimation({required this.color});

  @override
  State<_SpeakingRingAnimation> createState() => _SpeakingRingAnimationState();
}

class _SpeakingRingAnimationState extends State<_SpeakingRingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
      builder: (context, _) {
        return Container(
          width: 40 + _controller.value * 12,
          height: 40 + _controller.value * 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withOpacity(1.0 - _controller.value),
              width: 1.5,
            ),
          ),
        );
      },
    );
  }
}

// --- Action Button ---
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Error State ---
class _VoiceErrorCard extends StatelessWidget {
  final String message;
  const _VoiceErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<VoiceChatBloc>().add(const LeaveVoiceChannel());
            },
            child: Text(
              'Dismiss',
              style: GoogleFonts.outfit(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
