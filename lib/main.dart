import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to landscape orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Army Camp',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF2C3E50), // Dark military blue
        primaryColor: const Color(0xFF648C4C), // Military green
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF648C4C), // Military green
          secondary: const Color(0xFFCD7F32), // Bronze/military insignia color
          surface: const Color(0xFF34495E), // Darker military blue
          background: const Color(0xFF2C3E50), // Dark military blue
        ),
      ),
      home: const GameScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

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