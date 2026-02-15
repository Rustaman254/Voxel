import 'package:equatable/equatable.dart';

class Room extends Equatable {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final DateTime createdAt;
  final bool isPrivate;
  final List<RoomMember> members;
  final double x;
  final double y;
  final double latitude;
  final double longitude;

  const Room({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.createdAt,
    required this.isPrivate,
    required this.members,
    this.x = 0,
    this.y = 0,
    this.latitude = 0,
    this.longitude = 0,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      creatorId: json['creatorId'] ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      isPrivate: json['isPrivate'] ?? false,
      members: (json['members'] as List<dynamic>?)
              ?.map((e) => RoomMember.fromJson(e))
              .toList() ??
          [],
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'creatorId': creatorId,
      'createdAt': createdAt.toIso8601String(),
      'isPrivate': isPrivate,
      'members': members.map((e) => e.toJson()).toList(),
      'x': x,
      'y': y,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  List<Object?> get props => [id, name, description, creatorId, createdAt, isPrivate, members, x, y, latitude, longitude];
}

class RoomMember extends Equatable {
  final String userId;
  final String username;
  final String avatarUrl;
  final String role; // creator, admin, member
  final DateTime joinedAt;
  final List<String> permissions;

  const RoomMember({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.role,
    required this.joinedAt,
    required this.permissions,
  });

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      role: json['role'] ?? 'member',
      joinedAt: DateTime.parse(json['joinedAt'] ?? DateTime.now().toIso8601String()),
      permissions: (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'avatarUrl': avatarUrl,
      'role': role,
      'joinedAt': joinedAt.toIso8601String(),
      'permissions': permissions,
    };
  }

  @override
  List<Object?> get props => [userId, username, avatarUrl, role, joinedAt, permissions];
}
