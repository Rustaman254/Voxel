import 'package:equatable/equatable.dart';

class AvatarPosition extends Equatable {
  final String userId;
  final String username;
  final double x; // Top-down world x coordinate
  final double y; // Top-down world y coordinate
  final DateTime updatedAt;
  final String avatarUrl;
  final double latitude;
  final double longitude;
  final bool isTalking;
  final bool isVisible; // Whether user wants to be visible on map

  const AvatarPosition({
    required this.userId,
    this.username = '',
    required this.x,
    required this.y,
    required this.updatedAt,
    this.avatarUrl = '',
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.isTalking = false,
    this.isVisible = true, // Default to visible
  });

  AvatarPosition copyWith({
    String? userId,
    String? username,
    double? x,
    double? y,
    DateTime? updatedAt,
    String? avatarUrl,
    double? latitude,
    double? longitude,
    bool? isTalking,
    bool? isVisible,
  }) {
    return AvatarPosition(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      x: x ?? this.x,
      y: y ?? this.y,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isTalking: isTalking ?? this.isTalking,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  @override
  List<Object?> get props => [userId, username, x, y, updatedAt, avatarUrl, latitude, longitude, isTalking, isVisible];
}
