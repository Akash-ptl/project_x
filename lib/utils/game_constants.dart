import 'package:flutter/painting.dart';

// Game-wide color constants
class GameColors {
  // Military-themed color palette
  static const Color darkMilitaryBlue = Color(0xFF2C3E50);
  static const Color militaryGreen = Color(0xFF648C4C);
  static const Color lightMilitaryGreen = Color(0xFF8BA87E);
  static const Color bronzeInsigniaColor = Color(0xFFCD7F32);
  static const Color darkMilitaryBlueVariant = Color(0xFF34495E);
  static const Color lightMilitaryGrayGreen = Color(0xFFD0D9CB);
}

// Game configuration constants
class GameConfig {
  // Character movement and size
  static const double characterSize = 100.0;
  static const double movementSpeed = 5.0;

  // Map dimensions
  static const double mapWidth = 2000.0;
  static const double mapHeight = 1500.0;

  // Joystick configuration
  static const double joystickRadius = 60.0;
  static const double innerJoystickRadius = 25.0;

  // Animation settings
  static const int totalWalkFrames = 7;
  static const Duration walkAnimationDuration = Duration(milliseconds: 600);
}

// Asset paths
class GameAssets {
  static const String characterWalkSprite = 'assets/images/Walk.png';
}