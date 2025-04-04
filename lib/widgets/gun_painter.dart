import 'package:flutter/material.dart';
import 'dart:math' as math;

// Custom painter for the gun line
class GunPainter extends CustomPainter {
  final double angle;
  final double length;

  GunPainter({required this.angle, required this.length});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A) // Dark gun color
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final endPoint = center + Offset(
      math.cos(angle) * length,
      math.sin(angle) * length,
    );

    // Gun barrel
    canvas.drawLine(center, endPoint, paint);

    // Gun handle
    final handlePaint = Paint()
      ..color = const Color(0xFF8B4513) // Brown wooden handle
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // Draw handle perpendicular to barrel
    final handleAngle = angle + math.pi/2;
    final handleStart = center + Offset(
      math.cos(handleAngle) * 8,
      math.sin(handleAngle) * 8,
    );
    final handleEnd = center + Offset(
      math.cos(handleAngle) * 20,
      math.sin(handleAngle) * 20,
    );

    canvas.drawLine(handleStart, handleEnd, handlePaint);
  }

  @override
  bool shouldRepaint(covariant GunPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.length != length;
  }
}