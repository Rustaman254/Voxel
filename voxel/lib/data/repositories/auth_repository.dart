import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/user_profile.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  static const String _defaultUrl = 'http://192.168.1.4:8080';
  final String _baseUrl = const String.fromEnvironment('API_URL', defaultValue: _defaultUrl);
  final _storage = const FlutterSecureStorage();
  
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

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
        id: data['id'],
        displayName: data['displayName'],
        avatarUrl: data['avatarUrl'],
        email: data['email'] ?? '',
        username: data['username'] ?? '',
        authToken: data['authToken'] ?? '',
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
    final url = Uri.parse('$_baseUrl/api/auth/login');
    
    try {
      final response = await http.post(
        url,
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserProfile(
          id: data['userId'] ?? data['_id'] ?? data['id'] ?? 'user_123',
          displayName: data['displayName'] ?? data['username'] ?? email.split('@')[0],
          avatarUrl: data['avatarUrl'] ?? '',
          email: data['email'] ?? email,
          username: data['username'] ?? '',
        );

        // Save session
        final token = data['token'] ?? user.id;
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
      
      // DEMO MODE FALLBACK: If connection fails, allow login with any data for testing
      if (e.toString().contains('SocketException') || 
          e.toString().contains('TimeoutException') || 
          e.toString().contains('Connection refused')) {
        debugPrint('⚠️ Server unreachable. Entering DEMO MODE.');
        
        // Simulate a short delay for realism
        await Future.delayed(const Duration(milliseconds: 800));
        
        return UserProfile(
          id: 'demo_user',
          displayName: 'Demo Otter',
          avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=Felix',
          email: email,
          username: email.split('@')[0],
        );
      }
      rethrow;
    }
  }

  Future<UserProfile> signup(String email, String username, String displayName, String avatarUrl, String password) async {
    final url = Uri.parse('$_baseUrl/api/auth/signup');
    
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
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = UserProfile(
          id: data['userId'] ?? data['_id'] ?? data['id'],
          displayName: data['displayName'] ?? displayName,
          avatarUrl: data['avatarUrl'] ?? avatarUrl,
          email: data['email'] ?? email,
          username: data['username'] ?? username,
        );

        // Save session
        final token = data['token'] ?? user.id;
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
      
      // DEMO MODE FALLBACK
      if (e.toString().contains('SocketException') || 
          e.toString().contains('TimeoutException') || 
          e.toString().contains('Connection refused')) {
        debugPrint('⚠️ Server unreachable. Entering DEMO MODE.');
        
        final user = UserProfile(
          id: 'demo_user',
          displayName: displayName,
          avatarUrl: avatarUrl,
          email: email,
          username: username,
          authToken: 'demo_token',
        );
        
        await _saveSession('demo_token', user);
        return user;
      }
      rethrow;
    }
  }
}
