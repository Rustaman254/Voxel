import 'package:flutter/material.dart';
import '../../domain/entities/avatar_position.dart';
import 'dart:math' as math;
import 'forest_generator.dart';

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
    // Multi-layer grass background for depth
    final grassGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF7CB342), // Darker grass
        const Color(0xFF9CCC65), // Medium grass
        const Color(0xFFAED581), // Lighter grass
      ],
    );
    
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = grassGradient.createShader(Offset.zero & size),
    );

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final worldOriginX = centerX - (cameraX * zoom);
    final worldOriginY = centerY - (cameraY * zoom);

    // Paint definitions
    final darkTreePaint = Paint()..color = const Color(0xFF2E7D32);
    final mediumTreePaint = Paint()..color = const Color(0xFF388E3C);
    final lightTreePaint = Paint()..color = const Color(0xFF4CAF50);
    final trunkPaint = Paint()..color = const Color(0xFF5D4037);
    final darkTrunkPaint = Paint()..color = const Color(0xFF4E342E);
    final rockPaint = Paint()..color = const Color(0xFF78909C);
    final darkRockPaint = Paint()..color = const Color(0xFF546E7A);
    final pathPaint = Paint()..color = const Color(0xFFD7CCC8).withOpacity(0.6);
    final waterPaint = Paint()..color = const Color(0xFF4FC3F7).withOpacity(0.7);
    final bambooPaint = Paint()..color = const Color(0xFF558B2F);
    final flowerPaint = Paint()..color = const Color(0xFFFF4081);
    final bushPaint = Paint()..color = const Color(0xFF66BB6A);

    // Draw winding paths first
    _drawPaths(canvas, size, worldOriginX, worldOriginY, zoom, pathPaint);

    // Draw water features
    _drawWaterFeatures(canvas, size, worldOriginX, worldOriginY, zoom, waterPaint);

    const double cellSize = 80.0;

    // Use ForestGenerator to place elements
    for (int x = -15; x <= 35; x++) {
      for (int y = -15; y <= 35; y++) {
        final tx = worldOriginX + (x * cellSize * zoom);
        final ty = worldOriginY + (y * cellSize * zoom);
        
        // Only draw if visible on screen (with margin)
        if (tx > -100 && tx < size.width + 100 && ty > -100 && ty < size.height + 100) {
          final type = ForestGenerator.getElementAt(x, y);
          final pos = Offset(tx, ty);
          
          switch (type) {
            case ForestElementType.rock:
              _drawRock(canvas, pos, zoom, rockPaint, darkRockPaint);
              break;
            case ForestElementType.largeTree:
              _drawLargeTree(canvas, pos, zoom, darkTreePaint, mediumTreePaint, lightTreePaint, trunkPaint);
              break;
            case ForestElementType.mediumTree:
              _drawMediumTree(canvas, pos, zoom, mediumTreePaint, trunkPaint);
              break;
            case ForestElementType.bamboo:
              _drawBamboo(canvas, pos, zoom, bambooPaint, darkTrunkPaint);
              break;
            case ForestElementType.bush:
              _drawBush(canvas, pos, zoom, bushPaint, darkTreePaint);
              break;
            case ForestElementType.flower:
              _drawFlowers(canvas, pos, zoom, flowerPaint);
              break;
            case ForestElementType.none:
            case ForestElementType.water:
              break;
          }
        }
      }
    }
  }

  void _drawPaths(Canvas canvas, Size size, double worldOriginX, double worldOriginY, double zoom, Paint pathPaint) {
    // Draw a winding path across the map
    final path = Path();
    final points = [
      Offset(worldOriginX + (-200 * zoom), worldOriginY + (-100 * zoom)),
      Offset(worldOriginX + (0 * zoom), worldOriginY + (100 * zoom)),
      Offset(worldOriginX + (300 * zoom), worldOriginY + (200 * zoom)),
      Offset(worldOriginX + (600 * zoom), worldOriginY + (50 * zoom)),
      Offset(worldOriginX + (900 * zoom), worldOriginY + (300 * zoom)),
    ];
    
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        final prev = points[i - 1];
        final curr = points[i];
        final controlX = (prev.dx + curr.dx) / 2;
        final controlY = (prev.dy + curr.dy) / 2 + (30 * zoom);
        path.quadraticBezierTo(controlX, controlY, curr.dx, curr.dy);
      }
      
      canvas.drawPath(
        path,
        pathPaint..style = PaintingStyle.stroke..strokeWidth = 40 * zoom..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawWaterFeatures(Canvas canvas, Size size, double worldOriginX, double worldOriginY, double zoom, Paint waterPaint) {
    // Small pond
    final pondCenter = Offset(worldOriginX + (400 * zoom), worldOriginY + (-200 * zoom));
    canvas.drawCircle(pondCenter, 60 * zoom, waterPaint);
    canvas.drawCircle(pondCenter, 40 * zoom, waterPaint..color = const Color(0xFF29B6F6).withOpacity(0.5));
    
    // Stream
    final streamPath = Path();
    streamPath.moveTo(worldOriginX + (800 * zoom), worldOriginY + (-300 * zoom));
    streamPath.quadraticBezierTo(
      worldOriginX + (700 * zoom), worldOriginY + (-100 * zoom),
      worldOriginX + (750 * zoom), worldOriginY + (100 * zoom),
    );
    canvas.drawPath(
      streamPath,
      Paint()..color = const Color(0xFF4FC3F7).withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 20 * zoom..strokeCap = StrokeCap.round,
    );
  }

  void _drawLargeTree(Canvas canvas, Offset pos, double zoom, Paint darkPaint, Paint mediumPaint, Paint lightPaint, Paint trunkPaint) {
    // Trunk
    canvas.drawCircle(pos, 8 * zoom, trunkPaint);
    
    // Layered canopy for depth
    canvas.drawCircle(pos, 28 * zoom, darkPaint);
    canvas.drawCircle(pos.translate(-3 * zoom, -3 * zoom), 24 * zoom, mediumPaint);
    canvas.drawCircle(pos.translate(2 * zoom, -5 * zoom), 20 * zoom, lightPaint);
    
    // Highlight
    canvas.drawCircle(
      pos.translate(-6 * zoom, -8 * zoom),
      6 * zoom,
      Paint()..color = Colors.white.withOpacity(0.3),
    );
  }

  void _drawMediumTree(Canvas canvas, Offset pos, double zoom, Paint treePaint, Paint trunkPaint) {
    // Trunk
    canvas.drawCircle(pos, 5 * zoom, trunkPaint);
    
    // Canopy
    canvas.drawCircle(pos, 18 * zoom, treePaint);
    canvas.drawCircle(pos.translate(-2 * zoom, -3 * zoom), 14 * zoom, treePaint..color = const Color(0xFF4CAF50));
  }

  void _drawBamboo(Canvas canvas, Offset pos, double zoom, Paint bambooPaint, Paint segmentPaint) {
    // Draw 3-5 bamboo stalks
    for (int i = 0; i < 4; i++) {
      final offset = Offset(pos.dx + (i * 6 - 9) * zoom, pos.dy);
      final height = (40 + (i * 5)) * zoom;
      
      // Stalk
      canvas.drawLine(
        offset,
        offset.translate(0, -height),
        Paint()..color = bambooPaint.color..strokeWidth = 3 * zoom..strokeCap = StrokeCap.round,
      );
      
      // Segments
      for (int j = 1; j <= 3; j++) {
        canvas.drawCircle(
          offset.translate(0, -(height * j / 4)),
          2 * zoom,
          segmentPaint,
        );
      }
      
      // Leaves at top
      canvas.drawCircle(offset.translate(0, -height), 8 * zoom, Paint()..color = const Color(0xFF7CB342));
    }
  }

  void _drawBush(Canvas canvas, Offset pos, double zoom, Paint bushPaint, Paint darkPaint) {
    // Multiple overlapping circles for bushy appearance
    canvas.drawCircle(pos, 12 * zoom, darkPaint);
    canvas.drawCircle(pos.translate(-5 * zoom, 0), 10 * zoom, bushPaint);
    canvas.drawCircle(pos.translate(5 * zoom, 0), 10 * zoom, bushPaint);
    canvas.drawCircle(pos.translate(0, -5 * zoom), 10 * zoom, bushPaint);
  }

  void _drawRock(Canvas canvas, Offset pos, double zoom, Paint rockPaint, Paint darkRockPaint) {
    // Irregular rock shape using overlapping circles
    canvas.drawCircle(pos, 15 * zoom, darkRockPaint);
    canvas.drawCircle(pos.translate(-4 * zoom, -2 * zoom), 12 * zoom, rockPaint);
    canvas.drawCircle(pos.translate(3 * zoom, 1 * zoom), 10 * zoom, rockPaint);
    
    // Highlight
    canvas.drawCircle(
      pos.translate(-5 * zoom, -6 * zoom),
      4 * zoom,
      Paint()..color = Colors.white.withOpacity(0.4),
    );
  }

  void _drawFlowers(Canvas canvas, Offset pos, double zoom, Paint flowerPaint) {
    // Small cluster of flowers
    final colors = [
      const Color(0xFFFF4081),
      const Color(0xFFE91E63),
      const Color(0xFFF48FB1),
      const Color(0xFFFFEB3B),
    ];
    
    for (int i = 0; i < 5; i++) {
      final angle = (i * 2 * math.pi / 5);
      final offset = Offset(
        pos.dx + math.cos(angle) * 8 * zoom,
        pos.dy + math.sin(angle) * 8 * zoom,
      );
      canvas.drawCircle(offset, 3 * zoom, Paint()..color = colors[i % colors.length]);
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
