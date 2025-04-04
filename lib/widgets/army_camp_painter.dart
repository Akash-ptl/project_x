import 'package:flutter/material.dart';
import 'dart:math' as math;

// Custom painter for army camp background
class ArmyCampPainter extends CustomPainter {
  final double characterX;
  final double characterY;
  final List<Rect> tents;
  final List<Rect> obstacles;
  final List<Rect> decorations;
  final double mapWidth;
  final double mapHeight;

  ArmyCampPainter({
    required this.characterX,
    required this.characterY,
    required this.tents,
    required this.obstacles,
    required this.decorations,
    required this.mapWidth,
    required this.mapHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Base ground color - military dirt/soil
    final groundPaint = Paint()..color = const Color(0xFF5D4037); // Brown soil
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), groundPaint);

    // Tactical grid pattern
    final gridPaint = Paint()
      ..color = const Color(0xFF4A3429).withOpacity(0.3) // Darker brown
      ..strokeWidth = 1;

    // Draw grid lines
    final gridSize = 60.0;

    // Calculate grid offset based on character position
    final offsetX = characterX % gridSize;
    final offsetY = characterY % gridSize;

    // Calculate where to start drawing lines
    final startX = -offsetX;
    final startY = -offsetY;

    // Draw horizontal grid lines
    for (double y = startY; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw vertical grid lines
    for (double x = startX; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw ground decorations (terrain variations)
    final random = math.Random(42); // Fixed seed for consistent randomness
    final decorationPaint = Paint();

    for (int i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 5.0 + random.nextDouble() * 10.0;

      // Decide on decoration type
      final decorationType = random.nextInt(3);

      switch (decorationType) {
        case 0: // Dirt patch
          decorationPaint.color = const Color(0xFF4A3429).withOpacity(0.3);
          canvas.drawCircle(Offset(x, y), radius, decorationPaint);
          break;
        case 1: // Grass patch
          decorationPaint.color = const Color(0xFF556B2F).withOpacity(0.3);
          canvas.drawCircle(Offset(x, y), radius, decorationPaint);
          break;
        case 2: // Rocks
          decorationPaint.color = const Color(0xFF787878).withOpacity(0.4);
          canvas.drawCircle(Offset(x, y), radius, decorationPaint);
          break;
      }
    }

    // Apply translation based on character position
    canvas.save();
    canvas.translate(
        size.width / 2 - characterX,
        size.height / 2 - characterY
    );

    // Draw camp perimeter (large circular fence)
    final perimeterPaint = Paint()
      ..color = const Color(0xFF3E2723) // Dark brown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    canvas.drawCircle(
        Offset(mapWidth/2, mapHeight/2),
        math.min(mapWidth, mapHeight) * 0.45,
        perimeterPaint
    );

    // Draw entrance to the camp (gap in the perimeter)
    final entrancePaint = Paint()
      ..color = const Color(0xFF5D4037) // Brown soil (same as ground)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16;

    final entranceAngle = math.pi / 4; // 45 degrees
    final entranceSize = 60.0;
    final radius = math.min(mapWidth, mapHeight) * 0.45;

    final entranceStart = Offset(
        mapWidth/2 + radius * math.cos(entranceAngle - entranceSize/radius/2),
        mapHeight/2 + radius * math.sin(entranceAngle - entranceSize/radius/2)
    );

    final entranceEnd = Offset(
        mapWidth/2 + radius * math.cos(entranceAngle + entranceSize/radius/2),
        mapHeight/2 + radius * math.sin(entranceAngle + entranceSize/radius/2)
    );

    canvas.drawLine(entranceStart, entranceEnd, entrancePaint);

    // Draw watch towers at perimeter (4 towers at cardinal directions)
    final towerPaint = Paint()..color = const Color(0xFF3E2723); // Dark brown

    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2; // 0, 90, 180, 270 degrees
      // Skip the tower near the entrance
      if ((angle - entranceAngle).abs() < 0.5) continue;

      final towerCenter = Offset(
          mapWidth/2 + radius * math.cos(angle),
          mapHeight/2 + radius * math.sin(angle)
      );

      // Draw tower base
      canvas.drawRect(
          Rect.fromCenter(center: towerCenter, width: 40, height: 40),
          towerPaint
      );

      // Draw tower top
      canvas.drawRect(
          Rect.fromLTWH(towerCenter.dx - 25, towerCenter.dy - 25, 50, 25),
          towerPaint
      );
    }

    // Draw tents (military green with shadows)
    final tentPaint = Paint()..color = const Color(0xFF4B6043); // Military green
    final tentShadowPaint = Paint()..color = const Color(0xFF3A4A34); // Darker military green
    final tentRoofPaint = Paint()..color = const Color(0xFF60794D); // Lighter military green

    for (final tent in tents) {
      // Tent base
      canvas.drawRect(tent, tentPaint);

      // Tent roof (triangle)
      final tentPath = Path()
        ..moveTo(tent.left, tent.top)
        ..lineTo(tent.left + tent.width / 2, tent.top - tent.height * 0.4)
        ..lineTo(tent.right, tent.top)
        ..close();

      canvas.drawPath(tentPath, tentRoofPaint);

      // Tent entrance (darker rectangle)
      canvas.drawRect(
          Rect.fromLTWH(
              tent.left + tent.width * 0.4,
              tent.bottom - tent.height * 0.5,
              tent.width * 0.2,
              tent.height * 0.5
          ),
          tentShadowPaint
      );
    }

    // Draw obstacles (crates, barrels, sandbags)
    final obstaclePaint = Paint();

    for (final obstacle in obstacles) {
      // Randomize obstacle type
      final obstacleType = obstacle.width % 3;

      switch (obstacleType.toInt()) {
        case 0: // Wooden crate
          obstaclePaint.color = const Color(0xFF8B4513); // Brown
          canvas.drawRect(obstacle, obstaclePaint);

          // Crate lines
          final crateLine = Paint()
            ..color = const Color(0xFF5D2906) // Darker brown
            ..strokeWidth = 2;

          canvas.drawLine(
              Offset(obstacle.left, obstacle.top),
              Offset(obstacle.right, obstacle.top),
              crateLine
          );

          canvas.drawLine(
              Offset(obstacle.left, obstacle.center.dy),
              Offset(obstacle.right, obstacle.center.dy),
              crateLine
          );

          canvas.drawLine(
              Offset(obstacle.left, obstacle.top),
              Offset(obstacle.left, obstacle.bottom),
              crateLine
          );

          canvas.drawLine(
              Offset(obstacle.center.dx, obstacle.top),
              Offset(obstacle.center.dx, obstacle.bottom),
              crateLine
          );
          break;

        case 1: // Barrel
          obstaclePaint.color = const Color(0xFF4F4F4F); // Dark gray
          canvas.drawOval(obstacle, obstaclePaint);

          // Barrel ring
          final barrelRing = Paint()
            ..color = const Color(0xFF696969) // Lighter gray
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;

          canvas.drawOval(
              Rect.fromCenter(
                  center: obstacle.center,
                  width: obstacle.width * 0.95,
                  height: obstacle.height * 0.3
              ),
              barrelRing
          );
          break;

        case 2: // Sandbags
          obstaclePaint.color = const Color(0xFFBDB76B); // Khaki

          // Draw multiple sandbags
          for (int i = 0; i < 3; i++) {
            for (int j = 0; j < 2; j++) {
              final bagWidth = obstacle.width / 3;
              final bagHeight = obstacle.height / 2;

              canvas.drawRRect(
                  RRect.fromRectAndRadius(
                      Rect.fromLTWH(
                          obstacle.left + i * bagWidth,
                          obstacle.top + j * bagHeight,
                          bagWidth * 0.9,
                          bagHeight * 0.9
                      ),
                      const Radius.circular(5)
                  ),
                  obstaclePaint
              );
            }
          }
          break;
      }
    }

    // Draw decorations (flags, campfires, small military items)
    for (final decoration in decorations) {
      // Randomize decoration type
      final decorationType = decoration.width % 3;

      switch (decorationType.toInt()) {
        case 0: // Flag
        // Flag pole
          final flagPolePaint = Paint()
            ..color = const Color(0xFF8B4513) // Brown
            ..strokeWidth = 2;

          canvas.drawLine(
              Offset(decoration.center.dx, decoration.bottom),
              Offset(decoration.center.dx, decoration.top - decoration.height),
              flagPolePaint
          );

          // Flag
          final flagPaint = Paint()..color = const Color(0xFF8BA87E); // Military green

          final flagPath = Path()
            ..moveTo(decoration.center.dx, decoration.top - decoration.height)
            ..lineTo(decoration.center.dx + decoration.width, decoration.top - decoration.height * 0.7)
            ..lineTo(decoration.center.dx, decoration.top - decoration.height * 0.4)
            ..close();

          canvas.drawPath(flagPath, flagPaint);
          break;

        case 1: // Campfire
        // Logs
          final logPaint = Paint()..color = const Color(0xFF8B4513); // Brown

          canvas.drawRect(
              Rect.fromLTWH(
                  decoration.left,
                  decoration.center.dy,
                  decoration.width,
                  decoration.height * 0.2
              ),
              logPaint
          );

          canvas.drawRect(
              Rect.fromLTWH(
                  decoration.center.dx - decoration.width * 0.1,
                  decoration.top,
                  decoration.width * 0.2,
                  decoration.height
              ),
              logPaint
          );

          // Fire
          final firePaint = Paint()..color = const Color(0xFFFF7F00); // Orange

          canvas.drawCircle(
              decoration.center,
              decoration.width * 0.4,
              firePaint
          );
          break;

        case 2: // Ammo crate (small)
          final ammoPaint = Paint()..color = const Color(0xFF4F4F4F); // Dark gray

          canvas.drawRect(decoration, ammoPaint);

          // Ammo crate markings
          final markingsPaint = Paint()
            ..color = const Color(0xFFFFD700) // Gold/yellow
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1;

          canvas.drawLine(
              Offset(decoration.left, decoration.top),
              Offset(decoration.right, decoration.bottom),
              markingsPaint
          );

          canvas.drawLine(
              Offset(decoration.right, decoration.top),
              Offset(decoration.left, decoration.bottom),
              markingsPaint
          );
          break;
      }
    }

    // Restore the canvas
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ArmyCampPainter oldDelegate) {
    return oldDelegate.characterX != characterX ||
        oldDelegate.characterY != characterY;
  }
}