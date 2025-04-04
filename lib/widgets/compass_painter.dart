import 'package:flutter/material.dart';
import 'dart:math' as math;

// Compass painter
class CompassPainter extends CustomPainter {
  final double direction;

  CompassPainter({required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw compass background
    final bgPaint = Paint()
      ..color = const Color(0xFF3A4A34) // Military green
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius - 2, bgPaint);

    // Draw compass directions (N, E, S, W)
    final directionPaint = Paint()
      ..color = const Color(0xFFD0D9CB) // Light military gray-green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Draw cardinal lines
    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2;
      final start = center + Offset(
        math.cos(angle) * (radius * 0.5),
        math.sin(angle) * (radius * 0.5),
      );
      final end = center + Offset(
        math.cos(angle) * (radius * 0.8),
        math.sin(angle) * (radius * 0.8),
      );

      canvas.drawLine(start, end, directionPaint);
    }

    // Draw intercardinal lines (NE, SE, SW, NW)
    final minorDirPaint = Paint()
      ..color = const Color(0xFFD0D9CB).withOpacity(0.5) // Lighter color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 4; i++) {
      final angle = i * math.pi / 2 + math.pi / 4;
      final start = center + Offset(
        math.cos(angle) * (radius * 0.6),
        math.sin(angle) * (radius * 0.6),
      );
      final end = center + Offset(
        math.cos(angle) * (radius * 0.8),
        math.sin(angle) * (radius * 0.8),
      );

      canvas.drawLine(start, end, minorDirPaint);
    }

    // Draw compass pointer (red for north)
    final pointerPaint = Paint()
      ..color = const Color(0xFFCD7F32) // Bronze color
      ..style = PaintingStyle.fill;

    // Rotate to match the character's direction
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-direction); // Negative to make north point in the correct direction

    // Draw north pointer
    final northPath = Path()
      ..moveTo(0, -radius * 0.7)
      ..lineTo(radius * 0.1, -radius * 0.5)
      ..lineTo(-radius * 0.1, -radius * 0.5)
      ..close();

    canvas.drawPath(northPath, pointerPaint..color = const Color(0xFFE57373)); // Red for north

    // Draw south pointer
    final southPath = Path()
      ..moveTo(0, radius * 0.7)
      ..lineTo(radius * 0.08, radius * 0.5)
      ..lineTo(-radius * 0.08, radius * 0.5)
      ..close();

    canvas.drawPath(southPath, pointerPaint..color = const Color(0xFFD0D9CB)); // White for south

    // Center point
    canvas.drawCircle(
        Offset.zero,
        3,
        Paint()..color = const Color(0xFFD0D9CB)
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
    return oldDelegate.direction != direction;
  }
}