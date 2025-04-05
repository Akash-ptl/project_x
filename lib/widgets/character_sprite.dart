import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

// CharacterSprite widget to render the correct frame from the sprite sheet
class CharacterSprite extends StatelessWidget {
  final ui.Image image;
  final int frameIndex;
  final int totalFrames;
  final double size;
  final double direction;
  final bool isOverlay;

  const CharacterSprite({
    Key? key,
    required this.image,
    required this.frameIndex,
    required this.totalFrames,
    required this.size,
    required this.direction,
    this.isOverlay = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Transform(
        alignment: Alignment.center,
        // Flip horizontally based on direction
        transform: Matrix4.rotationY(
            (math.cos(direction) < 0) ? math.pi : 0
        ),
        child: CustomPaint(
          painter: SpritePainter(
            image: image,
            frameIndex: frameIndex,
            totalFrames: totalFrames,
            isOverlay: isOverlay,
          ),
          size: Size(size, size),
        ),
      ),
    );
  }
}

// SpritePainter to draw the specific frame from the sprite sheet
class SpritePainter extends CustomPainter {
  final ui.Image image;
  final int frameIndex;
  final int totalFrames;
  final bool isOverlay;

  SpritePainter({
    required this.image,
    required this.frameIndex,
    required this.totalFrames,
    this.isOverlay = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the width of a single frame - ensure it's an integer to avoid blurry sprites
    final frameWidth = (image.width / totalFrames).floorToDouble();
    final frameHeight = image.height.toDouble();

    // Source rectangle - which part of the sprite sheet to show
    // Make sure we're selecting the correct frame from the sprite sheet
    final src = Rect.fromLTWH(
      frameIndex * frameWidth,
      0,
      frameWidth,
      frameHeight,
    );

    // Destination rectangle - where to draw it on the canvas
    final dst = Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height,
    );

    // Create paint with blend mode if this is an overlay sprite
    final Paint paint = Paint();
    if (isOverlay) {
      // Use a blend mode appropriate for effects like firing or reloading
      paint.blendMode = BlendMode.srcOver;
      paint.filterQuality = FilterQuality.medium; // Improve quality for effects
    } else {
      // Better quality for character sprites
      paint.filterQuality = FilterQuality.medium;
    }

    // Draw the specific frame from the sprite sheet
    canvas.drawImageRect(image, src, dst, paint);

    // For debugging: show frame boundaries
    // final debugPaint = Paint()
    //   ..color = Colors.red
    //   ..style = PaintingStyle.stroke
    //   ..strokeWidth = 1.0;
    // canvas.drawRect(dst, debugPaint);
  }

  @override
  bool shouldRepaint(covariant SpritePainter oldDelegate) {
    return oldDelegate.frameIndex != frameIndex ||
        oldDelegate.isOverlay != isOverlay;
  }
}