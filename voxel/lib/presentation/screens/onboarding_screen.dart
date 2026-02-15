import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/auth_notifier.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      ref.read(authProvider.notifier).completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              _buildSlide(
                gradientColors: [const Color(0xFFFF6B9D), const Color(0xFFFF8FB3)],
                verticalText: 'organizer',
                imagePath: 'assets/images/pink_otter.png',
                title: 'Don\'t just float there. Organize your raft with VOXEL.',
                subtitle: 'We keep your events simpler than opening a clam on a rock.',
                buttonColor: Colors.white,
                buttonTextColor: const Color(0xFFFF6B9D),
                buttonText: 'Track Now',
              ),
              _buildSlide(
                backgroundColor: const Color(0xFFFAF9F6),
                verticalText: 'Notifier',
                verticalTextColor: const Color(0xFFFF6B9D).withOpacity(0.15),
                imagePath: 'assets/images/orange_otter.png',
                title: 'Keep your ears perked. Real-time updates so you never miss a voxel check.',
                subtitle: 'From \'Scheduled\' to \'Live\' — we\'re faster than an otter spotting a fish.',
                titleColor: const Color(0xFF2C2C2C),
                subtitleColor: const Color(0xFF5C5C5C),
                buttonColor: const Color(0xFFFF6B9D),
                buttonTextColor: Colors.white,
                buttonText: 'Get Updates',
              ),
              _buildSlide(
                gradientColors: [const Color(0xFF1A1A1A), const Color(0xFF2C2C2C)],
                verticalText: 'Protector',
                verticalTextColor: const Color(0xFFFFD700).withOpacity(0.15),
                imagePath: 'assets/images/yellow_otter.png',
                title: 'We guard your data like a favorite rock. Safe, secure, and otter-ly private.',
                subtitle: 'Encrypted, protected, and holding hands while we sleep so nothing drifts away.',
                buttonColor: const Color(0xFFFFD700),
                buttonTextColor: const Color(0xFF1A1A1A),
                buttonText: 'Started Tracking',
              ),
            ],
          ),
          // Page Indicators - moved to bottom left aligned with content
          Positioned(
            bottom: 40,
            left: 40,
            child: Row(
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? (_currentPage == 1 ? const Color(0xFFFF6B9D) : Colors.white)
                        : (_currentPage == 1 ? const Color(0xFFFF6B9D).withOpacity(0.4) : Colors.white.withOpacity(0.4)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide({
    List<Color>? gradientColors,
    Color? backgroundColor,
    required String verticalText,
    Color? verticalTextColor,
    required String imagePath,
    required String title,
    required String subtitle,
    Color titleColor = Colors.white,
    Color subtitleColor = Colors.white, // Made nullable to handle default
    required Color buttonColor,
    required Color buttonTextColor,
    required String buttonText,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        gradient: gradientColors != null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              )
            : null,
      ),
      child: SafeArea(
        child: Stack(
          children: [
            // Vertical Text - Left
            Positioned(
              left: 20,
              top: 60,
              bottom: 60,
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  verticalText,
                  style: GoogleFonts.outfit(
                    fontSize: 100, // Bigger size
                    fontWeight: FontWeight.w900,
                    color: verticalTextColor ?? Colors.white.withOpacity(0.3),
                    letterSpacing: 4,
                  ),
                ),
              ),
            ),
            
            // Otter Image - Right
            Positioned(
              right: -50, // Pushing it to the right edge
              top: 100,
              child: Image.asset(
                imagePath,
                height: 350, // Bigger image
                fit: BoxFit.contain,
              ),
            ),

            // Content - Bottom Left
            Positioned(
              left: 40,
              right: 40,
              bottom: 80, // Moved up to leave space for indicators
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // Left aligned
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    subtitle,
                    textAlign: TextAlign.left,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: subtitleColor == Colors.white 
                          ? Colors.white.withOpacity(0.9) 
                          : subtitleColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: buttonTextColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          buttonText,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
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
}
