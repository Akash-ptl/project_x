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

  const CharacterSprite({
    Key? key,
    required this.image,
    required this.frameIndex,
    required this.totalFrames,
    required this.size,
    required this.direction,
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

  SpritePainter({
    required this.image,
    required this.frameIndex,
    required this.totalFrames,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the width of a single frame
    final frameWidth = image.width / totalFrames;
    final frameHeight = image.height.toDouble();

    // Source rectangle - which part of the sprite sheet to show
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

    // Draw the specific frame from the sprite sheet
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(covariant SpritePainter oldDelegate) {
    return oldDelegate.frameIndex != frameIndex;
  }
}