import 'package:equatable/equatable.dart';

class VoxelEvent extends Equatable {
  final String id;
  final String title;
  final String description;
  final double x;
  final double y;
  final double latitude; // GPS coordinate
  final double longitude; // GPS coordinate
  final String creatorId;
  final DateTime startTime;
  final String eventType;
  final double ticketPrice;
  final bool hasTickets;
  final String voxelTheme;
  final String? attachedGameId;
  final bool isGpsEvent; // Whether event was created in GPS mode
  final String? parentEventId; // For sub-events
  final List<String> subEventIds; // List of sub-event IDs
  final int participantCount; // Current number of participants
  final String? gameId; // Game tied to this event

  const VoxelEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.x,
    required this.y,
    this.latitude = 0.0,
    this.longitude = 0.0,
    required this.creatorId,
    required this.startTime,
    this.eventType = 'GENERAL',
    this.ticketPrice = 0.0,
    this.hasTickets = false,
    this.voxelTheme = 'CLASSIC',
    this.attachedGameId,
    this.isGpsEvent = false,
    this.parentEventId,
    this.subEventIds = const [],
    this.participantCount = 0,
    this.gameId,
  });

  bool get isHot => participantCount > 10;

  @override
  List<Object?> get props => [
    id, title, description, x, y, latitude, longitude, creatorId, startTime, 
    eventType, ticketPrice, hasTickets, voxelTheme, attachedGameId,
    isGpsEvent, parentEventId, subEventIds, participantCount, gameId
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'x': x,
    'y': y,
    'latitude': latitude,
    'longitude': longitude,
    'creatorId': creatorId,
    'startTime': startTime.toIso8601String(),
    'eventType': eventType,
    'ticketPrice': ticketPrice,
    'hasTickets': hasTickets,
    'voxelTheme': voxelTheme,
    'attachedGameId': attachedGameId,
    'isGpsEvent': isGpsEvent,
    'parentEventId': parentEventId,
    'subEventIds': subEventIds,
    'participantCount': participantCount,
    'gameId': gameId,
  };

  factory VoxelEvent.fromJson(Map<String, dynamic> json) {
    // Map database fields: 'x' and 'y' in DB are actually latitude and longitude (GPS coordinates)
    final lat = (json['x'] as num?)?.toDouble() ?? (json['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (json['y'] as num?)?.toDouble() ?? (json['longitude'] as num?)?.toDouble() ?? 0.0;
    
    return VoxelEvent(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      description: json['description'],
      x: lat, // GPS latitude
      y: lng, // GPS longitude
      latitude: lat,
      longitude: lng,
      creatorId: json['creatorId'],
      startTime: json['startTime'] is String ? DateTime.parse(json['startTime']) : (json['startTime'] as DateTime),
      eventType: json['eventType'] ?? 'GENERAL',
      ticketPrice: (json['ticketPrice'] as num?)?.toDouble() ?? 0.0,
      hasTickets: json['hasTickets'] ?? false,
      voxelTheme: json['voxelTheme'] ?? 'CLASSIC',
      attachedGameId: json['attachedGameId'],
      isGpsEvent: true, // If it has GPS coordinates, it's a GPS event
      parentEventId: json['parentEventId'],
      subEventIds: (json['subEventIds'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      participantCount: json['participantCount'] ?? 0,
      gameId: json['gameId'],
    );
  }
}
