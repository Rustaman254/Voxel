import 'package:equatable/equatable.dart';

class VoxelEvent extends Equatable {
  final String id;
  final String title;
  final String description;
  final double x;
  final double y;
  final String creatorId;
  final DateTime startTime;
  final String eventType;
  final double ticketPrice;
  final bool hasTickets;
  final String voxelTheme;
  final String? attachedGameId;

  const VoxelEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.x,
    required this.y,
    required this.creatorId,
    required this.startTime,
    this.eventType = 'GENERAL',
    this.ticketPrice = 0.0,
    this.hasTickets = false,
    this.voxelTheme = 'CLASSIC',
    this.attachedGameId,
  });

  @override
  List<Object?> get props => [
    id, title, description, x, y, creatorId, startTime, 
    eventType, ticketPrice, hasTickets, voxelTheme, attachedGameId
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'x': x,
    'y': y,
    'creatorId': creatorId,
    'startTime': startTime.toIso8601String(),
    'eventType': eventType,
    'ticketPrice': ticketPrice,
    'hasTickets': hasTickets,
    'voxelTheme': voxelTheme,
    'attachedGameId': attachedGameId,
  };

  factory VoxelEvent.fromJson(Map<String, dynamic> json) => VoxelEvent(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    creatorId: json['creatorId'],
    startTime: DateTime.parse(json['startTime']),
    eventType: json['eventType'] ?? 'GENERAL',
    ticketPrice: (json['ticketPrice'] as num?)?.toDouble() ?? 0.0,
    hasTickets: json['hasTickets'] ?? false,
    voxelTheme: json['voxelTheme'] ?? 'CLASSIC',
    attachedGameId: json['attachedGameId'],
  );
}
