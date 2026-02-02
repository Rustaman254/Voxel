import 'package:flutter/material.dart';
import 'dart:math' as math;

class VoxelEngine {
  // Isometric projection constants - exactly matching the Smashy Road perspective
  // Typically Smashy Road uses a slightly steeper angle than standard 30-degree isometric
  static const double isoAngle = 0.610865; // ~35 degrees
  static final double cosIso = math.cos(isoAngle);
  static final double sinIso = math.sin(isoAngle);

  /// Converts 3D grid coordinates to 2D screen coordinates
  static Offset project(double x, double y, double z, double cellSize, Offset origin) {
    // Standard isometric formula with adjusted angle
    final double sx = (x - y) * cosIso * cellSize;
    final double sy = (x + y) * sinIso * cellSize - (z * cellSize);
    
    return Offset(origin.dx + sx, origin.dy + sy);
  }

  /// Draws a high-fidelity voxel cube with Smashy Road style shading
  static void drawVoxel(
    Canvas canvas, 
    double x, 
    double y, 
    double z, 
    double size, 
    Offset origin, 
    Color color, {
    bool drawOutline = true,
  }) {
    // Face vertices
    final Offset top = project(x, y, z + 1, size, origin);
    final Offset left = project(x + 1, y, z, size, origin);
    final Offset right = project(x, y + 1, z, size, origin);
    final Offset bottom = project(x + 1, y + 1, z, size, origin);
    
    final Offset midLeft = project(x + 1, y, z + 1, size, origin);
    final Offset midRight = project(x, y + 1, z + 1, size, origin);
    final Offset midBottom = project(x + 1, y + 1, z + 1, size, origin);

    // Smashy Road Shading:
    // Top is brightest (direct sun)
    // Left/Right sides are significantly darker to provide volume
    final Color topColor = color;
    final Color leftSideColor = _adjustColor(color, -25);
    final Color rightSideColor = _adjustColor(color, -10);

    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Paint outlinePaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // 1. Top Face
    final Path topPath = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(midLeft.dx, midLeft.dy)
      ..lineTo(midBottom.dx, midBottom.dy)
      ..lineTo(midRight.dx, midRight.dy)
      ..close();
    canvas.drawPath(topPath, paint..color = topColor);
    if (drawOutline) canvas.drawPath(topPath, outlinePaint);

    // 2. Left Face
    final Path leftPath = Path()
      ..moveTo(midLeft.dx, midLeft.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(midBottom.dx, midBottom.dy)
      ..close();
    canvas.drawPath(leftPath, paint..color = leftSideColor);
    if (drawOutline) canvas.drawPath(leftPath, outlinePaint);

    // 3. Right Face
    final Path rightPath = Path()
      ..moveTo(midRight.dx, midRight.dy)
      ..lineTo(midBottom.dx, midBottom.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(rightPath, paint..color = rightSideColor);
    if (drawOutline) canvas.drawPath(rightPath, outlinePaint);
  }

  static Color _adjustColor(Color color, int amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + (amount / 100)).clamp(0.0, 1.0)).toColor();
  }
}
