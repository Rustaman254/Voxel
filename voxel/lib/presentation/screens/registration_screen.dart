import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/auth_notifier.dart';
import '../utils/toast_service.dart';
import 'dart:math';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  
  // Expanded avatar seeds list
  bool _isLoading = false;
  final List<String> _avatarSeeds = [
    'Felix', 'Aneka', 'Bob', 'Jack', 'Milly', 'Zoe', 
    'Alexander', 'Willow', 'Oliver', 'Leo', 'Max', 'Luna',
    'Ginger', 'Abby', 'Bella', 'Charlie', 'Daisy', 'Sadie',
    'Buddy', 'Lola', 'Rocky', 'Lucy', 'Bailey', 'Scout'
  ];
  
  String _selectedSeed = 'Felix';

  @override
  void initState() {
    super.initState();
    // Random default seed
    _selectedSeed = _avatarSeeds[Random().nextInt(_avatarSeeds.length)];
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
           // Background accents
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB452FF).withOpacity(0.05),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'CREATE ACCOUNT',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.black,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'JOIN THE RAFT',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFB452FF),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  _buildSectionHeader('CHOOSE YOUR AVATAR'),
                  const SizedBox(height: 16),
                  
                  // Avatar Grid
                  SizedBox(
                    height: 120, // Reduced height as per standard UI
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
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
                          child: Container(
                            margin: const EdgeInsets.only(right: 16),
                            width: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: isSelected ? const Color(0xFFB452FF) : Colors.transparent, 
                                width: 3
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? const Color(0xFFB452FF).withOpacity(0.2) : Colors.black.withOpacity(0.05), 
                                  blurRadius: 10, 
                                  spreadRadius: 1
                                ),
                              ],
                            ),
                            child: ClipOval( // Ensure image is clipped
                              child: Stack(
                                children: [
                                  Image.network(url, fit: BoxFit.cover, width: 80, height: 80),
                                  if (isSelected)
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFB452FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, size: 10, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Form
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInputField(
                          controller: _displayNameController, 
                          label: 'Display Name',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _usernameController, 
                          label: 'Username',
                          icon: Icons.alternate_email,
                          prefixText: '@',
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          controller: _emailController, 
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        _buildPasswordField(),
                        
                        const SizedBox(height: 32),
                        
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSignup,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB452FF),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading 
                                ? const SizedBox(
                                    height: 24, 
                                    width: 24, 
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                  ) 
                                : Text(
                                    'CREATE ACCOUNT',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16, 
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
    return Center(
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.grey[500],
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? prefixText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87
          ),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            prefixIcon: Icon(icon, color: Colors.grey[400]),
            prefixText: prefixText,
            prefixStyle: GoogleFonts.outfit(
              fontSize: 16, 
              fontWeight: FontWeight.w600, 
              color: const Color(0xFFB452FF)
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFB452FF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSignup() async {
    if (_displayNameController.text.trim().isEmpty || 
        _usernameController.text.trim().isEmpty || 
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ToastService.showError(context, 'Please fill in all fields');
      return;
    }

    if (_passwordController.text.length < 6) {
      ToastService.showError(context, 'Password must be at least 6 characters');
      return;
    }

    final avatarUrl = 'https://api.dicebear.com/9.x/adventurer/png?seed=$_selectedSeed&backgroundColor=transparent';
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    setState(() => _isLoading = true);

    try {
      await ref.read(authProvider.notifier).signup(
            email, 
            username, 
            displayName, 
            avatarUrl,
            password,
          );
      if (mounted) {
        Navigator.of(context).pop(); // Go back to login, or main will switch to World
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(context, e.toString().replaceAll('Exception: ', ''));
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PASSWORD',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87
          ),
          decoration: InputDecoration(
            hintText: 'Enter Password',
            prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[400],
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFB452FF), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
