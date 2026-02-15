import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/auth_notifier.dart';
import '../widgets/voxel_avatar.dart';
import '../utils/toast_service.dart';
import 'dart:math';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _displayNameController;
  bool _isLoading = false;
  
  final List<String> _avatarSeeds = [
    'Felix', 'Aneka', 'Bob', 'Jack', 'Milly', 'Zoe', 
    'Alexander', 'Willow', 'Oliver', 'Leo', 'Max', 'Luna',
    'Ginger', 'Abby', 'Bella', 'Charlie', 'Daisy', 'Sadie',
    'Buddy', 'Lola', 'Rocky', 'Lucy', 'Bailey', 'Scout'
  ];
  
  String _selectedSeed = 'Felix';
  String _currentAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _displayNameController = TextEditingController(text: user?.displayName ?? '');
    _currentAvatarUrl = user?.avatarUrl ?? '';
    
    // Extract seed from current avatar URL
    if (_currentAvatarUrl.isNotEmpty) {
      final seedMatch = RegExp(r'seed=([^&]+)').firstMatch(_currentAvatarUrl);
      if (seedMatch != null) {
        _selectedSeed = seedMatch.group(1) ?? 'Felix';
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final newAvatarUrl = 'https://api.dicebear.com/9.x/adventurer/svg?seed=$_selectedSeed&backgroundColor=transparent';
      final newDisplayName = _displayNameController.text.trim();
      
      if (newDisplayName.isEmpty) {
        ToastService.showError(context, 'Display name cannot be empty');
        setState(() => _isLoading = false);
        return;
      }
      
      // Call backend API
      await ref.read(authProvider.notifier).updateProfile(
        newDisplayName,
        newAvatarUrl,
      );
      
      if (mounted) {
        ToastService.showSuccess(context, 'Profile updated successfully! 🎉');
        setState(() {
          _isLoading = false;
          _currentAvatarUrl = newAvatarUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastService.showError(context, 'Failed to update profile: ${e.toString().replaceAll('Exception: ', '')}');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Logout',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB452FF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Logout', style: GoogleFonts.outfit(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        ToastService.showSuccess(context, 'Logged out successfully');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user data')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.outfit(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current Avatar Display
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFB452FF),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB452FF).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: VoxelAvatar(
                    avatarUrl: 'https://api.dicebear.com/9.x/adventurer/svg?seed=$_selectedSeed&backgroundColor=transparent',
                    radius: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Username
            Center(
              child: Text(
                '@${user.username}',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFB452FF),
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Avatar Selection
            _buildSectionHeader('CHOOSE AVATAR'),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _avatarSeeds.length,
                itemBuilder: (context, index) {
                  final seed = _avatarSeeds[index];
                  final isSelected = _selectedSeed == seed;
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSeed = seed;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFB452FF) : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected 
                                ? const Color(0xFFB452FF).withOpacity(0.2)
                                : Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: VoxelAvatar(
                          avatarUrl: 'https://api.dicebear.com/9.x/adventurer/svg?seed=$seed&backgroundColor=transparent',
                          radius: 35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            
            // User Info
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoField(
                    label: 'DISPLAY NAME',
                    controller: _displayNameController,
                    editable: true,
                  ),
                  const SizedBox(height: 20),
                  _buildInfoField(
                    label: 'USERNAME',
                    value: user.username,
                    editable: false,
                  ),
                  const SizedBox(height: 20),
                  _buildInfoField(
                    label: 'EMAIL',
                    value: user.email,
                    editable: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Save Button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
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
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'SAVE CHANGES',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Logout Button
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: _handleLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'LOGOUT',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildInfoField({
    required String label,
    TextEditingController? controller,
    String? value,
    required bool editable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        if (editable && controller != null)
          TextField(
            controller: controller,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFB452FF), width: 1.5),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value ?? '',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }
}
