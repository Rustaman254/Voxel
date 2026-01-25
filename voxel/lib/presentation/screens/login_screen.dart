import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/auth_notifier.dart';
import 'dart:math';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _usernameController;
  
  final List<String> _randomUserNames = [
    'Dark Phoenix', 'Lightning', 'Obsidian Fury', 'MasterChiefff', 'Rustaman', 'Jack', 'Milly', 'Zoe', 
    'Alexander', 'Willow', 'Oliver', 'Leo', 'Max', 'Luna'
  ];
  
  final List<String> _avatarSeeds = [
    'Felix', 'Aneka', 'Bob', 'Jack', 'Milly', 'Zoe', 
    'Alexander', 'Willow', 'Oliver', 'Leo', 'Max', 'Luna'
  ];
  
  String _selectedSeed = 'Felix';

  @override
  void initState() {
    super.initState();
    final random = Random();
    final randomIndex = random.nextInt(_randomUserNames.length);
    final initialName = _randomUserNames[randomIndex];
    _usernameController = TextEditingController(text: initialName);
    
    // Sync avatar seed with random name if it exists in avatar seeds
    if (_avatarSeeds.contains(initialName)) {
      _selectedSeed = initialName;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          // Background accent
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB452FF).withOpacity(0.1),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'VOXEL WORLD',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CHOOSE YOUR AVATAR',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFB452FF),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Avatar Grid
                  Expanded(
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                      ),
                      itemCount: _avatarSeeds.length,
                      itemBuilder: (context, index) {
                        final seed = _avatarSeeds[index];
                        final isSelected = _selectedSeed == seed;
                        final url = 'https://api.dicebear.com/9.x/adventurer/png?seed=$seed&backgroundColor=transparent';
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSeed = seed;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: isSelected ? const Color(0xFFB452FF) : Colors.transparent, 
                                width: 4
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? const Color(0xFFB452FF).withOpacity(0.2) : Colors.black.withOpacity(0.05), 
                                  blurRadius: 15, 
                                  spreadRadius: 2
                                ),
                              ],
                              image: DecorationImage(
                                image: NetworkImage(url),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Login Form Card
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSectionHeader('YOUR IDENTITY'),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _usernameController,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Display Name',
                            hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
                            filled: true,
                            fillColor: const Color(0xFFF8F9FA),
                            contentPadding: const EdgeInsets.symmetric(vertical: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: const BorderSide(color: Color(0xFFB452FF), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 64,
                          child: ElevatedButton(
                            onPressed: authState.isLoading ? null : () {
                              if (_usernameController.text.trim().isEmpty) return;
                              
                              final avatarUrl = 'https://api.dicebear.com/9.x/adventurer/png?seed=$_selectedSeed&backgroundColor=transparent';
                              
                              ref.read(authProvider.notifier).login(
                                    _usernameController.text,
                                    avatarUrl,
                                  );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB452FF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(32),
                              ),
                            ),
                            child: authState.isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : Text(
                                    'LET\'S VIBE 🚀',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18, 
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.grey[500],
        letterSpacing: 2,
      ),
    );
  }
}


