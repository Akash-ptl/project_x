import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../widgets/character_sprite.dart';
import '../widgets/gun_painter.dart';
import '../widgets/army_camp_painter.dart';
import '../widgets/compass_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // Character position
  double _characterX = 0.0;
  double _characterY = 0.0;

  // Gun direction in radians
  double _gunDirection = 0.0;

  // Character size
  final double _characterSize = 100.0;

  // Movement speed
  final double _movementSpeed = 5.0;

  // Animation controllers
  late AnimationController _walkAnimController;
  bool _isWalking = false;

  // Walking direction
  double _facingDirection = 0;

  // Joystick controls
  bool _movementJoystickActive = false;
  Offset _movementJoystickPosition = Offset.zero;
  Offset _movementJoystickDelta = Offset.zero;

  bool _gunJoystickActive = false;
  Offset _gunJoystickPosition = Offset.zero;
  Offset _gunJoystickDelta = Offset.zero;

  final double _joystickRadius = 60.0;
  final double _innerJoystickRadius = 25.0;

  // Current frame for walking animation
  int _currentWalkFrame = 0;
  final int _totalWalkFrames = 7; // Based on your sprite sheet with 7 frames

  // Movement direction
  double _moveDirectionX = 0.0;
  double _moveDirectionY = 0.0;

  // Images
  ui.Image? characterImage;
  ui.Image? backgroundImage;
  bool isCharacterImageLoaded = false;
  bool isBackgroundImageLoaded = false;

  // Obstacle positions
  final List<Rect> _obstacles = [];
  final List<Rect> _tents = [];
  final List<Rect> _decorations = [];

  // Map size (larger than screen)
  final double mapWidth = 2000.0;
  final double mapHeight = 1500.0;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _walkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Adjust animation speed here
    );

    _walkAnimController.addListener(() {
      if (_isWalking) {
        setState(() {
          // Calculate current frame based on animation value
          _currentWalkFrame = (_walkAnimController.value * _totalWalkFrames).floor() % _totalWalkFrames;
        });
      }
    });

    _walkAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _walkAnimController.reset();
        _walkAnimController.forward();
      }
    });

    // Create army camp obstacles and decorations
    _generateArmyCamp();

    // Load character sprite sheet
    _loadCharacterImage();

    // Start the game loop
    _startGameLoop();
  }

  void _generateArmyCamp() {
    // Generate random obstacles to represent military equipment, barracks, etc.
    final random = math.Random();

    // Tents (larger structures)
    for (int i = 0; i < 8; i++) {
      final width = 120.0 + random.nextDouble() * 60.0;
      final height = 80.0 + random.nextDouble() * 40.0;
      final x = random.nextDouble() * (mapWidth - width);
      final y = random.nextDouble() * (mapHeight - height);

      // Don't place tents in the center where the player starts
      if ((x - mapWidth/2).abs() < 200 && (y - mapHeight/2).abs() < 200) {
        continue;
      }

      _tents.add(Rect.fromLTWH(x, y, width, height));
    }

    // Obstacles (smaller structures like crates, barriers)
    for (int i = 0; i < 20; i++) {
      final size = 30.0 + random.nextDouble() * 40.0;
      final x = random.nextDouble() * (mapWidth - size);
      final y = random.nextDouble() * (mapHeight - size);

      // Don't place obstacles in the center where the player starts
      if ((x - mapWidth/2).abs() < 150 && (y - mapHeight/2).abs() < 150) {
        continue;
      }

      _obstacles.add(Rect.fromLTWH(x, y, size, size));
    }

    // Decorations (very small items like flags, campfires)
    for (int i = 0; i < 30; i++) {
      final size = 10.0 + random.nextDouble() * 20.0;
      final x = random.nextDouble() * (mapWidth - size);
      final y = random.nextDouble() * (mapHeight - size);
      _decorations.add(Rect.fromLTWH(x, y, size, size));
    }
  }

  Future<void> _loadCharacterImage() async {
    try {
      // Load the asset as bytes
      final ByteData data = await rootBundle.load('assets/images/Walk.png');
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode the image
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();

      setState(() {
        characterImage = frameInfo.image;
        isCharacterImageLoaded = true;
      });
    } catch (e) {
      print('Error loading character image: $e');
    }
  }

  @override
  void dispose() {
    _walkAnimController.dispose();
    super.dispose();
  }

  void _startGameLoop() {
    Future.doWhile(() async {
      // Update character position based on joystick input
      if (_movementJoystickActive && _movementJoystickDelta.distance > 10) {
        // Start walking animation if not already walking
        if (!_isWalking) {
          _isWalking = true;
          _walkAnimController.forward();
        }

        // Calculate potential new position
        double newX = _characterX + _moveDirectionX * _movementSpeed;
        double newY = _characterY + _moveDirectionY * _movementSpeed;

        // Check map boundaries
        newX = newX.clamp(-mapWidth/2 + _characterSize/2, mapWidth/2 - _characterSize/2);
        newY = newY.clamp(-mapHeight/2 + _characterSize/2, mapHeight/2 - _characterSize/2);

        // Create character rect for collision detection
        final characterRect = Rect.fromCenter(
          center: Offset(newX, newY),
          width: _characterSize * 0.6, // Make collision box smaller than visual character
          height: _characterSize * 0.6,
        );

        // Check collisions with obstacles
        bool collisionDetected = false;
        for (final obstacle in _obstacles) {
          final adjustedObstacle = Rect.fromLTWH(
            obstacle.left - mapWidth/2,
            obstacle.top - mapHeight/2,
            obstacle.width,
            obstacle.height,
          );

          if (characterRect.overlaps(adjustedObstacle)) {
            collisionDetected = true;
            break;
          }
        }

        // Check collisions with tents
        for (final tent in _tents) {
          final adjustedTent = Rect.fromLTWH(
            tent.left - mapWidth/2,
            tent.top - mapHeight/2,
            tent.width,
            tent.height,
          );

          if (characterRect.overlaps(adjustedTent)) {
            collisionDetected = true;
            break;
          }
        }

        // Update position if no collision
        if (!collisionDetected) {
          setState(() {
            _characterX = newX;
            _characterY = newY;
            // Update facing direction for the character
            _facingDirection = math.atan2(_moveDirectionY, _moveDirectionX);
          });
        }
      } else if (_isWalking) {
        // Stop walking animation
        _isWalking = false;
        _walkAnimController.stop();
        setState(() {
          _currentWalkFrame = 0; // Reset to idle pose
        });
      }

      // Wait for next frame
      await Future.delayed(const Duration(milliseconds: 16)); // ~60FPS
      return true; // Continue the loop
    });
  }

  // Handle movement joystick
  void _handleMovementJoystickStart(Offset position) {
    setState(() {
      _movementJoystickActive = true;
      _movementJoystickPosition = position;
      _movementJoystickDelta = Offset.zero;
    });
  }

  void _handleMovementJoystickUpdate(Offset position) {
    if (!_movementJoystickActive) return;

    Offset delta = position - _movementJoystickPosition;
    double distance = delta.distance;

    // Limit the delta to the joystick radius
    if (distance > _joystickRadius) {
      delta = delta * (_joystickRadius / distance);
      distance = _joystickRadius;
    }

    setState(() {
      _movementJoystickDelta = delta;

      // Calculate movement direction
      if (distance > 10.0) {
        // Normalize delta
        _moveDirectionX = delta.dx / distance;
        _moveDirectionY = delta.dy / distance;
      } else {
        _moveDirectionX = 0;
        _moveDirectionY = 0;
      }
    });
  }

  void _handleMovementJoystickEnd() {
    setState(() {
      _movementJoystickActive = false;
      _movementJoystickDelta = Offset.zero;
      _moveDirectionX = 0;
      _moveDirectionY = 0;
    });
  }

  // Handle gun joystick
  void _handleGunJoystickStart(Offset position) {
    setState(() {
      _gunJoystickActive = true;
      _gunJoystickPosition = position;
      _gunJoystickDelta = Offset.zero;
    });
  }

  void _handleGunJoystickUpdate(Offset position) {
    if (!_gunJoystickActive) return;

    Offset delta = position - _gunJoystickPosition;
    double distance = delta.distance;

    // Limit the delta to the joystick radius
    if (distance > _joystickRadius) {
      delta = delta * (_joystickRadius / distance);
      distance = _joystickRadius;
    }

    setState(() {
      _gunJoystickDelta = delta;

      // Calculate gun direction
      if (distance > 10.0) {
        _gunDirection = math.atan2(delta.dy, delta.dx);
      }
    });
  }

  void _handleGunJoystickEnd() {
    setState(() {
      _gunJoystickActive = false;
      _gunJoystickDelta = Offset.zero;
    });
  }

  Widget _buildJoystick(Offset delta) {
    return Container(
      width: _joystickRadius * 2,
      height: _joystickRadius * 2,
      decoration: BoxDecoration(
        color: const Color(0xFF344D25).withOpacity(0.2), // Military green with transparency
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF8BA87E), // Light military green
          width: 2,
        ),
      ),
      child: Center(
        child: Transform.translate(
          offset: delta,
          child: Container(
            width: _innerJoystickRadius * 2,
            height: _innerJoystickRadius * 2,
            decoration: BoxDecoration(
              color: const Color(0xFF8BA87E), // Light military green
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8BA87E).withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoystickIndicator(String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF344D25).withOpacity(0.2), // Military green with transparency
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8BA87E), // Light military green
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD0D9CB), // Light military gray-green
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Icon(
            Icons.touch_app,
            color: Color(0xFFD0D9CB), // Light military gray-green
            size: 32,
          ),
        ],
      ),
    );
  }

  Widget _buildCharacter() {
    if (!isCharacterImageLoaded || characterImage == null) {
      // Show placeholder while image loads
      return Container(
        width: _characterSize,
        height: _characterSize,
        decoration: const BoxDecoration(
          color: Color(0xFF8BA87E), // Light military green
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Text(
            "Loading...",
            style: TextStyle(color: Colors.black),
          ),
        ),
      );
    }

    return SizedBox(
      width: _characterSize,
      height: _characterSize,
      child: Stack(
        children: [
          // Character sprite
          CharacterSprite(
            image: characterImage!,
            frameIndex: _currentWalkFrame,
            totalFrames: _totalWalkFrames,
            size: _characterSize,
            direction: _facingDirection,
          ),

          // Gun as a simple line
          CustomPaint(
            size: Size(_characterSize, _characterSize),
            painter: GunPainter(
              angle: _gunDirection,
              length: 50,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: GestureDetector(
        onPanStart: (details) {
          final position = details.localPosition;
          if (position.dx < screenSize.width / 2) {
            // Left side of screen - movement joystick
            _handleMovementJoystickStart(position);
          } else {
            // Right side of screen - gun direction joystick
            _handleGunJoystickStart(position);
          }
        },
        onPanUpdate: (details) {
          final position = details.localPosition;
          if (position.dx < screenSize.width / 2) {
            // Left side of screen - movement joystick
            _handleMovementJoystickUpdate(position);
          } else {
            // Right side of screen - gun direction joystick
            _handleGunJoystickUpdate(position);
          }
        },
        onPanEnd: (details) {
          if (_movementJoystickActive) {
            _handleMovementJoystickEnd();
          }
          if (_gunJoystickActive) {
            _handleGunJoystickEnd();
          }
        },
        child: Stack(
          children: [
            // Army Camp background with tactical grid pattern
            CustomPaint(
              size: Size(screenSize.width, screenSize.height),
              painter: ArmyCampPainter(
                characterX: _characterX,
                characterY: _characterY,
                tents: _tents,
                obstacles: _obstacles,
                decorations: _decorations,
                mapWidth: mapWidth,
                mapHeight: mapHeight,
              ),
            ),

            // Character with gun
            Positioned(
              left: screenSize.width / 2 - _characterSize / 2,
              top: screenSize.height / 2 - _characterSize / 2,
              child: _buildCharacter(),
            ),

            // Movement joystick (left side)
            if (_movementJoystickActive)
              Positioned(
                left: _movementJoystickPosition.dx - _joystickRadius,
                top: _movementJoystickPosition.dy - _joystickRadius,
                child: _buildJoystick(_movementJoystickDelta),
              ),

            // Gun direction joystick (right side)
            if (_gunJoystickActive)
              Positioned(
                left: _gunJoystickPosition.dx - _joystickRadius,
                top: _gunJoystickPosition.dy - _joystickRadius,
                child: _buildJoystick(_gunJoystickDelta),
              ),

            // Movement joystick indicator when not active
            Positioned(
              left: 30,
              bottom: 30,
              child: _buildJoystickIndicator("MOVEMENT"),
            ),

            // Gun direction joystick indicator when not active
            Positioned(
              right: 30,
              bottom: 30,
              child: _buildJoystickIndicator("GUN DIRECTION"),
            ),

            // HUD Info panel
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF344D25).withOpacity(0.5), // Military green with transparency
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF8BA87E), // Light military green
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Military rank icon
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8BA87E).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(
                          Icons.military_tech,
                          color: Color(0xFFD0D9CB),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'POSITION: (${_characterX.toStringAsFixed(0)}, ${_characterY.toStringAsFixed(0)}) | ANGLE: ${(_gunDirection * 180 / math.pi).toStringAsFixed(0)}°',
                        style: const TextStyle(
                          color: Color(0xFFD0D9CB), // Light military gray-green
                          fontSize: 14,
                          fontFamily: 'Courier', // Military-style monospace font
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Compass in top-right corner
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF344D25).withOpacity(0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF8BA87E),
                    width: 2,
                  ),
                ),
                child: CustomPaint(
                  painter: CompassPainter(direction: _facingDirection),
                  size: const Size(60, 60),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}