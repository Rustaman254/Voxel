import 'package:flutter/material.dart';
import '../../domain/entities/avatar_position.dart';
import 'dart:math' as math;

class WorldPainter extends CustomPainter {
  final double cameraX;
  final double cameraY;
  final double zoom;
  final AvatarPosition? myPosition;
  final List<AvatarPosition> peers;
  final double proximityRadius;
  final String? voxelTheme;
  final bool isEventWorld;

  WorldPainter({
    required this.cameraX,
    required this.cameraY,
    required this.zoom,
    required this.myPosition,
    required this.peers,
    this.proximityRadius = 50.0,
    this.voxelTheme,
    this.isEventWorld = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (voxelTheme == 'FOREST') {
      _drawForest(canvas, size);
    } else if (voxelTheme == 'CLASSIC') {
      _drawClassic(canvas, size);
    } else {
      _drawSimpleBackground(canvas, size);
    }
    
    // Draw Grid Overlay
    _drawGrid(canvas, size);
  }

  void _drawSimpleBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF8F9FA),
    );
  }

  void _drawForest(Canvas canvas, Size size) {
    // Grass background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF9CCC65),
    );

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final worldOriginX = centerX - (cameraX * zoom);
    final worldOriginY = centerY - (cameraY * zoom);

    // Draw some trees based on world coordinates
    final treePaint = Paint()..color = const Color(0xFF388E3C);
    final trunkPaint = Paint()..color = const Color(0xFF5D4037);

    // Use a pseudo-random seed based on position to keep trees consistent
    for (int x = -10; x <= 30; x++) {
      for (int y = -10; y <= 30; y++) {
        // Simple procedural placement
        final seed = (x * 73856093) ^ (y * 19349663);
        if (seed % 7 == 0) {
          final tx = worldOriginX + (x * 100 * zoom);
          final ty = worldOriginY + (y * 100 * zoom);
          
          if (tx > -50 && tx < size.width + 50 && ty > -50 && ty < size.height + 50) {
             // Draw a simple top-down tree
             canvas.drawCircle(Offset(tx, ty), 15 * zoom, treePaint);
             canvas.drawCircle(Offset(tx, ty), 5 * zoom, trunkPaint);
          }
        }
      }
    }
  }

  void _drawClassic(Canvas canvas, Size size) {
    // Concrete background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFEEEEEE),
    );

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final worldOriginX = centerX - (cameraX * zoom);
    final worldOriginY = centerY - (cameraY * zoom);

    final roadPaint = Paint()..color = const Color(0xFFBDBDBD);
    final buildingPaint = Paint()..color = const Color(0xFFE0E0E0);
    final sidewalkPaint = Paint()..color = const Color(0xFFF5F5F5);

    double blockSize = 200.0 * zoom;

    for (int x = -5; x <= 15; x++) {
      for (int y = -5; y <= 15; y++) {
        final bx = worldOriginX + (x * blockSize);
        final by = worldOriginY + (y * blockSize);

        if (bx > -blockSize && bx < size.width + blockSize && by > -blockSize && by < size.height + blockSize) {
           // Draw block
           canvas.drawRect(Rect.fromLTWH(bx + 10*zoom, by + 10*zoom, blockSize - 20*zoom, blockSize - 20*zoom), sidewalkPaint);
           canvas.drawRect(Rect.fromLTWH(bx + 40*zoom, by + 40*zoom, blockSize - 80*zoom, blockSize - 80*zoom), buildingPaint);
           
           // Draw Road lines
           final linePaint = Paint()..color = Colors.white.withOpacity(0.5)..strokeWidth = 2*zoom;
           canvas.drawLine(Offset(bx, by + blockSize/2), Offset(bx + blockSize, by + blockSize/2), linePaint);
           canvas.drawLine(Offset(bx + blockSize/2, by), Offset(bx + blockSize/2, by + blockSize), linePaint);
        }
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    const double spacing = 40.0; 
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    final worldOriginScreenX = centerX - (cameraX * zoom);
    final worldOriginScreenY = centerY - (cameraY * zoom);
    
    final startCol = (-worldOriginScreenX / spacing).floor();
    final endCol = ((size.width - worldOriginScreenX) / spacing).ceil();

    final startRow = (-worldOriginScreenY / spacing).floor();
    final endRow = ((size.height - worldOriginScreenY) / spacing).ceil();

    final dotPaint = Paint()..color = const Color(0xFFB452FF).withOpacity(0.15); // Use primary theme color

    for (int col = startCol; col <= endCol; col++) {
      for (int row = startRow; row <= endRow; row++) {
        final sx = worldOriginScreenX + col * spacing;
        final sy = worldOriginScreenY + row * spacing;
        
        canvas.drawCircle(Offset(sx, sy), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WorldPainter oldDelegate) {
    return oldDelegate.cameraX != cameraX ||
           oldDelegate.cameraY != cameraY ||
           oldDelegate.zoom != zoom ||
           oldDelegate.myPosition != myPosition ||
           oldDelegate.peers != peers ||
           oldDelegate.voxelTheme != voxelTheme ||
           oldDelegate.isEventWorld != isEventWorld;
  }
}
