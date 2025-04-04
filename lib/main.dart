import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Character Movement',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
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

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  // Character position
  double _characterX = 0.0;
  double _characterY = 0.0;

  // Camera angle in radians
  double _cameraAngle = 0.0;

  // Character size
  final double _characterSize = 60.0;

  // Movement speed
  final double _movementSpeed = 3.0;

  // Camera rotation speed in radians
  final double _rotationSpeed = 0.1;

  // Joystick control
  bool _joystickActive = false;
  Offset _joystickPosition = Offset.zero;
  Offset _joystickDelta = Offset.zero;
  final double _joystickRadius = 60.0;
  final double _innerJoystickRadius = 25.0;

  // Continuous movement
  bool _isMoving = false;
  double _moveDirectionX = 0.0;
  double _moveDirectionY = 0.0;

  // Animation controller for character
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    // Set up animation ticker for smooth movement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAnimationTicker();
    });
  }

  void _setupAnimationTicker() {
    const frameDuration = Duration(milliseconds: 16); // ~60 FPS

    Future<void> updateLoop() async {
      while (mounted) {
        await Future.delayed(frameDuration);
        if (_isMoving && mounted) {
          setState(() {
            _characterX += _moveDirectionX * _movementSpeed;
            _characterY += _moveDirectionY * _movementSpeed;
          });
        }
      }
    }

    updateLoop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Change camera angle
  void _changeCameraAngle(String direction) {
    setState(() {
      if (direction == 'left') {
        _cameraAngle -= _rotationSpeed;
      } else {
        _cameraAngle += _rotationSpeed;
      }

      // Normalize angle to 0-2π
      _cameraAngle %= (2 * math.pi);
    });
  }

  // Handle joystick movement
  void _handleJoystickStart(Offset position) {
    setState(() {
      _joystickActive = true;
      _joystickPosition = position;
      _joystickDelta = Offset.zero;
      _isMoving = false;
    });
  }

  void _handleJoystickUpdate(Offset position) {
    if (!_joystickActive) return;

    Offset delta = position - _joystickPosition;
    double distance = delta.distance;

    // Limit the delta to the joystick radius
    if (distance > _joystickRadius) {
      delta = delta * (_joystickRadius / distance);
      distance = _joystickRadius;
    }

    setState(() {
      _joystickDelta = delta;

      // Calculate movement direction relative to camera angle
      if (distance > 10.0) { // Small threshold to prevent tiny movements
        _isMoving = true;

        // Normalize delta
        double normalizedX = delta.dx / distance;
        double normalizedY = delta.dy / distance;

        // Apply camera rotation to movement direction
        _moveDirectionX = normalizedX * math.cos(_cameraAngle) + normalizedY * math.sin(_cameraAngle);
        _moveDirectionY = normalizedY * math.cos(_cameraAngle) - normalizedX * math.sin(_cameraAngle);
      } else {
        _isMoving = false;
      }
    });
  }

  void _handleJoystickEnd() {
    setState(() {
      _joystickActive = false;
      _joystickDelta = Offset.zero;
      _isMoving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width / 2;
    final centerY = screenSize.height / 2;

    return Scaffold(
      body: GestureDetector(
        onPanStart: (details) {
          // Only activate joystick in the lower left quadrant
          if (details.localPosition.dx < screenSize.width / 2 &&
              details.localPosition.dy > screenSize.height / 2) {
            _handleJoystickStart(details.localPosition);
          }
        },
        onPanUpdate: (details) {
          _handleJoystickUpdate(details.localPosition);
        },
        onPanEnd: (_) {
          _handleJoystickEnd();
        },
        child: Stack(
          children: [
            // Game world with colorful tiles
            CustomPaint(
              size: Size(screenSize.width, screenSize.height),
              painter: ColorfulTilesPainter(
                cameraAngle: _cameraAngle,
                characterX: _characterX,
                characterY: _characterY,
              ),
            ),

            // Character
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Positioned(
                  left: centerX - _characterSize / 2,
                  top: centerY - _characterSize / 2,
                  child: Transform.rotate(
                    angle: _isMoving ? math.atan2(_moveDirectionY, _moveDirectionX) : 0,
                    child: Container(
                      width: _characterSize,
                      height: _characterSize,
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.5),
                            blurRadius: 10.0 * (1 + 0.2 * math.sin(_controller.value * math.pi)),
                            spreadRadius: 5.0 * (1 + 0.1 * math.sin(_controller.value * math.pi)),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Joystick (only visible when active)
            if (_joystickActive)
              Positioned(
                left: _joystickPosition.dx - _joystickRadius,
                top: _joystickPosition.dy - _joystickRadius,
                child: Container(
                  width: _joystickRadius * 2,
                  height: _joystickRadius * 2,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Transform.translate(
                      offset: _joystickDelta,
                      child: Container(
                        width: _innerJoystickRadius * 2,
                        height: _innerJoystickRadius * 2,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Camera controls
            Positioned(
              right: 20,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'CAMERA',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildCameraButton('left', Icons.rotate_left),
                            const SizedBox(width: 24),
                            _buildCameraButton('right', Icons.rotate_right),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Joystick indicator when not active
            Positioned(
              left: 30,
              bottom: 30,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'TOUCH HERE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 8),
                    Icon(
                      Icons.touch_app,
                      color: Colors.blue,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'FOR JOYSTICK',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Info panel
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Text(
                    'Position: (${_characterX.toStringAsFixed(1)}, ${_characterY.toStringAsFixed(1)}) | Angle: ${(_cameraAngle * 180 / math.pi).toStringAsFixed(1)}°',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraButton(String direction, IconData icon) {
    return Container(
      margin: const EdgeInsets.all(4.0),
      child: ElevatedButton(
        onPressed: () => _changeCameraAngle(direction),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(16),
          elevation: 12,
        ),
        child: Icon(icon, size: 28),
      ),
    );
  }
}

// Custom painter to draw colorful infinite tiles
class ColorfulTilesPainter extends CustomPainter {
  final double cameraAngle;
  final double characterX;
  final double characterY;

  ColorfulTilesPainter({
    required this.cameraAngle,
    required this.characterX,
    required this.characterY,
  });

  // List of vibrant colors for tiles
  final List<Color> tileColors = [
    Colors.purple.shade300,
    Colors.blue.shade300,
    Colors.green.shade300,
    Colors.yellow.shade300,
    Colors.orange.shade300,
    Colors.red.shade300,
    Colors.pink.shade300,
    Colors.teal.shade300,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Save the canvas state
    canvas.save();

    // Translate to center and rotate
    canvas.translate(centerX, centerY);
    canvas.rotate(cameraAngle);

    // Apply character offset (inverted to create illusion of character movement)
    canvas.translate(-characterX, -characterY);

    final tileSize = 80.0;
    final visibleTilesX = (size.width / tileSize).ceil() + 2;
    final visibleTilesY = (size.height / tileSize).ceil() + 2;

    // Calculate starting tile coordinates to cover the visible area
    final startX = (characterX / tileSize).floor() - visibleTilesX ~/ 2;
    final startY = (characterY / tileSize).floor() - visibleTilesY ~/ 2;

    // Draw the tiles
    for (int x = startX; x < startX + visibleTilesX; x++) {
      for (int y = startY; y < startY + visibleTilesY; y++) {
        // Determine color based on position to create a pattern
        // Use a consistent pattern based on coordinates
        final colorIndex = ((x % 3) + (y % 3) * 3) % tileColors.length;
        final tileColor = tileColors[colorIndex];

        // Create tile with slight gradient effect
        final rect = Rect.fromLTWH(
            x * tileSize,
            y * tileSize,
            tileSize,
            tileSize
        );

        final paint = Paint()..color = tileColor;

        // Add a border to each tile
        canvas.drawRect(rect, paint);

        // Draw border
        final borderPaint = Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawRect(rect, borderPaint);

        // Add a subtle pattern inside each tile for visual interest
        final patternPaint = Paint()
          ..color = Colors.white.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        // Draw diagonal line
        canvas.drawLine(
            Offset(x * tileSize, y * tileSize),
            Offset(x * tileSize + tileSize, y * tileSize + tileSize),
            patternPaint
        );

        canvas.drawLine(
            Offset(x * tileSize + tileSize, y * tileSize),
            Offset(x * tileSize, y * tileSize + tileSize),
            patternPaint
        );
      }
    }

    // Draw coordinate axes for reference
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 2.0;

    // X-axis
    canvas.drawLine(
        Offset(-1000, 0),
        Offset(1000, 0),
        axisPaint
    );

    // Y-axis
    canvas.drawLine(
        Offset(0, -1000),
        Offset(0, 1000),
        axisPaint
    );

    // Draw grid markers
    final markerPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.0;

    for (int i = -10; i <= 10; i++) {
      // X-axis markers
      canvas.drawLine(
          Offset(i * tileSize * 5, -10),
          Offset(i * tileSize * 5, 10),
          markerPaint
      );

      // Y-axis markers
      canvas.drawLine(
          Offset(-10, i * tileSize * 5),
          Offset(10, i * tileSize * 5),
          markerPaint
      );
    }

    // Restore the canvas state
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ColorfulTilesPainter oldDelegate) {
    return oldDelegate.cameraAngle != cameraAngle ||
        oldDelegate.characterX != characterX ||
        oldDelegate.characterY != characterY;
  }
}