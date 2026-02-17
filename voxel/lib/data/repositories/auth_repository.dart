import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user_profile.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform; // Added for Platform.isAndroid
import '../../core/services/network_config_service.dart';

class AuthRepository {
  String get baseUrl {
    final service = NetworkConfigService();
    // Initialize if not already done (lazy load fallback)
    return service.apiBaseUrl;
  }
  final _storage = const FlutterSecureStorage();
  
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _onboardingKey = 'onboarding_completed';

  Future<void> setOnboardingCompleted(bool completed) async {
    await _storage.write(key: _onboardingKey, value: completed.toString());
  }

  Future<bool> isOnboardingCompleted() async {
    final value = await _storage.read(key: _onboardingKey);
    return value == 'true';
  }

  Future<void> _saveSession(String token, UserProfile user) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: jsonEncode({
      'id': user.id,
      'displayName': user.displayName,
      'avatarUrl': user.avatarUrl,
      'email': user.email,
      'username': user.username,
      'authToken': token,
    }));
  }

  Future<UserProfile?> getPersistedUser() async {
    final userData = await _storage.read(key: _userKey);
    if (userData == null) return null;
    
    try {
      final data = jsonDecode(userData);
      return UserProfile(
        id: data['id']?.toString() ?? data['userId']?.toString() ?? '',
        displayName: data['displayName']?.toString() ?? '',
        avatarUrl: data['avatarUrl']?.toString() ?? '',
        email: data['email']?.toString() ?? '',
        username: data['username']?.toString() ?? '',
        authToken: data['authToken']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('Error decoding persisted user: $e');
      return null;
    }
  }

  Future<String?> getPersistedToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<UserProfile> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/login');
    debugPrint('🌐 Attempting login at: $url');
    
    try {
      final response = await http.post(
        url,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📥 Login success data: $data');
        
        final user = UserProfile(
          id: (data['userId'] ?? data['id'])?.toString() ?? '',
          displayName: data['displayName']?.toString() ?? '',
          avatarUrl: data['avatarUrl']?.toString() ?? '',
          email: email,
          username: data['username']?.toString() ?? '',
        );

        // Save session
        final token = data['token']?.toString() ?? user.id;
        final userWithToken = UserProfile(
          id: user.id,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
          email: user.email,
          username: user.username,
          authToken: token,
        );
        
        await _saveSession(token, userWithToken);
        
        return userWithToken;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Login failed');
      }
    } catch (e) {
      debugPrint('Login API Error: $e');
      rethrow;
    }
  }

  Future<UserProfile> signup(String email, String username, String displayName, String avatarUrl, String password) async {
    final url = Uri.parse('$baseUrl/api/auth/signup');
    debugPrint('🌐 Attempting signup at: $url');
    
    try {
      final response = await http.post(
        url,
        body: jsonEncode({
          'email': email,
          'username': username,
          'displayName': displayName,
          'avatarUrl': avatarUrl,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('📥 Signup success data: $data');
        
        final user = UserProfile(
          id: (data['userId'] ?? data['id'])?.toString() ?? '',
          displayName: data['displayName']?.toString() ?? '',
          avatarUrl: data['avatarUrl']?.toString() ?? '',
          email: email,
          username: data['username']?.toString() ?? '',
        );

        // Save session
        final token = data['token']?.toString() ?? user.id;
        final userWithToken = UserProfile(
          id: user.id,
          displayName: user.displayName,
          avatarUrl: user.avatarUrl,
          email: user.email,
          username: user.username,
          authToken: token,
        );
        
        await _saveSession(token, userWithToken);

        return userWithToken;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Signup failed');
      }
    } catch (e) {
      debugPrint('Signup API Error: $e');
      rethrow;
    }
  }

  Future<UserProfile> updateProfile(String userId, String displayName, String avatarUrl, String token) async {
    final url = Uri.parse('$baseUrl/api/user/profile');
    debugPrint('🌐 Updating profile at: $url');
    
    try {
      final response = await http.put(
        url,
        body: jsonEncode({
          'displayName': displayName,
          'avatarUrl': avatarUrl,
        }),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('📥 Profile update success: $data');
        
        // Create updated user profile
        final updatedUser = UserProfile(
          id: userId,
          displayName: displayName,
          avatarUrl: avatarUrl,
          email: '', // Will be filled from current user
          username: '', // Will be filled from current user
          authToken: token,
        );
        
        // Update stored session
        await _saveSession(token, updatedUser);
        
        return updatedUser;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Profile update failed');
      }
    } catch (e) {
      debugPrint('Profile Update API Error: $e');
      rethrow;
    }
  }
}
