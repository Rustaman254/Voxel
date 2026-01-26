import 'dart:math';
import 'package:flutter/material.dart';

enum ForestElementType {
  none,
  largeTree,
  mediumTree,
  bamboo,
  bush,
  rock,
  flower,
  water, // For future use if we grid-ify water
}

class ForestGenerator {
  // Check what exists at a specific grid coordinate
  static ForestElementType getElementAt(int gridX, int gridY) {
    final seed = (gridX * 73856093) ^ (gridY * 19349663);
    
    // Rocks (15% chance)
    if (seed % 20 == 0) return ForestElementType.rock;
    
    // Large trees (25% chance)
    if (seed % 7 == 0) return ForestElementType.largeTree;
    
    // Medium trees (20% chance)
    if (seed % 9 == 1) return ForestElementType.mediumTree;
    
    // Bamboo clusters (10% chance)
    if (seed % 13 == 2) return ForestElementType.bamboo;
    
    // Bushes (15% chance)
    if (seed % 11 == 3) return ForestElementType.bush;
    
    // Flower patches (5% chance)
    if (seed % 23 == 4) return ForestElementType.flower;
    
    return ForestElementType.none;
  }

  // Get world position for a grid coordinate
  static Offset getPosition(int gridX, int gridY, double cellSize) {
    return Offset(gridX * cellSize, gridY * cellSize);
  }

  // Check collision for a world position
  static bool isPositionBlocked(double worldX, double worldY) {
    // Convert world position to grid coordinates
    // We assume density is roughly 1 item per 80-100 units based on painter
    const double cellSize = 80.0;
    
    final gridX = (worldX / cellSize).round();
    final gridY = (worldY / cellSize).round();
    
    // Check if we are close to the center of the grid cell
    final cellCenter = getPosition(gridX, gridY, cellSize);
    final dist = sqrt(pow(worldX - cellCenter.dx, 2) + pow(worldY - cellCenter.dy, 2));
    
    final type = getElementAt(gridX, gridY);
    
    // Define collision radii for blocking elements
    switch (type) {
      case ForestElementType.largeTree:
        return dist < 25.0; // Large tree trunk/base collision
      case ForestElementType.mediumTree:
        return dist < 15.0;
      case ForestElementType.rock:
        return dist < 20.0;
      case ForestElementType.bamboo:
        return dist < 20.0; // Bamboo cluster
      case ForestElementType.water:
        // Simple water collision if we implemented grid-based water
        // Complex water is path-based, handled separately or ignored for now
        return false;
      default:
        return false; // Bushes and flowers are walkthrough
    }
  }
}
