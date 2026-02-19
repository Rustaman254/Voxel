import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class NetworkConfigService {
  static final NetworkConfigService _instance = NetworkConfigService._internal();
  factory NetworkConfigService() => _instance;
  NetworkConfigService._internal();

  final _storage = const FlutterSecureStorage();
  static const String _ipKey = 'server_ip';
  
  // Default fallback IP
  String _currentIp = '192.168.31.194'; 
  
  String get currentIp => _currentIp;

  Future<void> init() async {
    try {
      final savedIp = await _storage.read(key: _ipKey);
      if (savedIp != null && savedIp.isNotEmpty) {
        _currentIp = savedIp;
      } else {
        // Set default based on platform if not saved
        if (!kIsWeb && Platform.isAndroid) {
          _currentIp = '192.168.31.194';
        } else {
           _currentIp = '192.168.31.194';
        }
      }
      debugPrint('🌐 NetworkConfig initialized with IP: $_currentIp');
      debugPrint('🌐 Running in ${kReleaseMode ? "RELEASE" : "DEBUG"} mode');
    } catch (e) {
      debugPrint('⚠️ Failed to load network config: $e');
    }
  }

  String get apiBaseUrl {
    // In production (release mode), use production server or saved IP
    if (kReleaseMode) {
      // You can replace this with your production server URL
      // For now, using the saved/default IP
      return 'http://$_currentIp:8080';
    }
    
    // In development mode
    if (kIsWeb) return 'http://localhost:8080';
    return 'http://$_currentIp:8080';
  }

  String get wsBaseUrl {
    // In production (release mode), use production server or saved IP
    if (kReleaseMode) {
      return 'ws://$_currentIp:8080/ws';
    }
    
    // In development mode
    if (kIsWeb) return 'ws://localhost:8080/ws';
    return 'ws://$_currentIp:8080/ws';
  }

  Future<void> setServerIp(String ip) async {
    if (ip.trim().isEmpty) return;
    _currentIp = ip.trim();
    await _storage.write(key: _ipKey, value: _currentIp);
    debugPrint('🌐 Server IP updated to: $_currentIp');
  }
}
