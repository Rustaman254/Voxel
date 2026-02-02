import 'package:flutter/material.dart';
import 'dart:math' as math;

enum SmashyCellType {
  asphalt,
  grass,
  building,
  sidewalk,
  roadLine,
  intersection,
  prop,
}

class SmashyObject {
  final SmashyCellType type;
  final int height;
  final Color color;
  final String? label;

  SmashyObject({
    required this.type,
    this.height = 1,
    required this.color,
    this.label,
  });
}

class SmashyWorldGenerator {
  static const int blockSize = 10; // 10x10 units per block
  static const int roadWidth = 4;  // 4 units wide road (2 lanes each way)
  
  /// Get the object at specific grid coordinates
  static SmashyObject getObjectAt(int x, int y) {
    final int seed = _getSeed(x, y);
    final random = math.Random(seed);

    // 1. Road Grid Logic
    // Roads are 4 units wide, every 'blockSize + roadWidth' units
    final int cycle = blockSize + roadWidth;
    final int relX = x % cycle;
    final int relY = y % cycle;
    
    // Convert to positive relative coords for periodic patterns
    final int px = relX < 0 ? relX + cycle : relX;
    final int py = relY < 0 ? relY + cycle : relY;

    final bool isVerticalRoad = px >= blockSize;
    final bool isHorizontalRoad = py >= blockSize;

    // Intersections
    if (isVerticalRoad && isHorizontalRoad) {
      return SmashyObject(
        type: SmashyCellType.intersection,
        color: const Color(0xFF37474F), // Slightly darker asphalt
      );
    }

    // Roads
    if (isVerticalRoad || isHorizontalRoad) {
       // Road markings
       bool isLine = false;
       if (isVerticalRoad) {
          // Center dashed line
          if (px == blockSize + roadWidth ~/ 2 && py % 2 == 0) isLine = true;
       } else {
          // Horizontal center dashed line
          if (py == blockSize + roadWidth ~/ 2 && px % 2 == 0) isLine = true;
       }

       if (isLine) {
         return SmashyObject(type: SmashyCellType.roadLine, color: Colors.white);
       }

       return SmashyObject(type: SmashyCellType.asphalt, color: const Color(0xFF455A64));
    }

    // 2. Sidewalks
    if (px == 0 || px == blockSize - 1 || py == 0 || py == blockSize - 1) {
      return SmashyObject(type: SmashyCellType.sidewalk, color: const Color(0xFF90A4AE));
    }

    // 3. Buildings & Parks inside the blocks
    // Every block has its own seed-based ID
    final int blockX = (x / cycle).floor();
    final int blockY = (y / cycle).floor();
    final int blockSeed = _getSeed(blockX, blockY);
    final blockRandom = math.Random(blockSeed);

    // Some blocks are parks, most are buildings
    final bool isPark = blockRandom.nextInt(10) < 2;

    if (isPark) {
       // Check if it's a tree spot
       if (random.nextInt(15) == 0) {
          return SmashyObject(type: SmashyCellType.prop, height: 2, color: const Color(0xFF2E7D32)); // Simple Tree
       }
       return SmashyObject(type: SmashyCellType.grass, color: const Color(0xFF7CB342));
    } else {
       // Central building in the block
       // We leave a 1-unit gap inside sidewalk for variety, or fill it
       if (px > 1 && px < blockSize - 2 && py > 1 && py < blockSize - 2) {
          final int height = 3 + blockRandom.nextInt(12);
          final Color buildingColor = _getBuildingColor(blockRandom);
          return SmashyObject(
            type: SmashyCellType.building, 
            height: height, 
            color: buildingColor,
            label: height > 8 ? "TOWER" : null,
          );
       }
       // Fill rest of block with pavement or small structures
       return SmashyObject(type: SmashyCellType.sidewalk, color: const Color(0xFFCFD8DC));
    }
  }

  static int _getSeed(int x, int y) {
    return (x * 73856093) ^ (y * 19349663);
  }

  static Color _getBuildingColor(math.Random random) {
    final colors = [
      const Color(0xFFCFD8DC), // Default grey
      const Color(0xFF90A4AE), // Dark grey
      const Color(0xFFFFCCbc), // Peach
      const Color(0xFFB3E5FC), // Light blue
      const Color(0xFFFFECB3), // Yellow
      const Color(0xFFC8E6C9), // Greenish
      const Color(0xFFF8BBD0), // Pinkish
    ];
    return colors[random.nextInt(colors.length)];
  }

  /// Collision check
  static bool isBlocked(int x, int y) {
    final obj = getObjectAt(x, y);
    return obj.type == SmashyCellType.building || (obj.type == SmashyCellType.prop && obj.height > 1);
  }
}
