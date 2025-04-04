import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

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
      title: 'Character Movement',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
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

class _GameScreenState extends State<GameScreen> {
  // Character position
  double _characterX = 0.0;
  double _characterY = 0.0;

  // Gun direction in radians
  double _gunDirection = 0.0;

  // Character size
  final double _characterSize = 60.0;

  // Movement speed
  final double _movementSpeed = 5.0;

  // Joystick controls
  bool _movementJoystickActive = false;
  Offset _movementJoystickPosition = Offset.zero;
  Offset _movementJoystickDelta = Offset.zero;

  bool _gunJoystickActive = false;
  Offset _gunJoystickPosition = Offset.zero;
  Offset _gunJoystickDelta = Offset.zero;

  final double _joystickRadius = 60.0;
  final double _innerJoystickRadius = 25.0;

  // Movement direction
  double _moveDirectionX = 0.0;
  double _moveDirectionY = 0.0;

  @override
  void initState() {
    super.initState();
    // Start the game loop
    _startGameLoop();
  }

  void _startGameLoop() {
    Future.doWhile(() async {
      // Update character position based on joystick input
      if (_movementJoystickActive && _movementJoystickDelta.distance > 10) {
        setState(() {
          _characterX += _moveDirectionX * _movementSpeed;
          _characterY += _moveDirectionY * _movementSpeed;
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
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
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
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.5),
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
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          const Icon(
            Icons.touch_app,
            color: Colors.white,
            size: 32,
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
            // Character with gun
            Positioned(
              left: screenSize.width / 2 + _characterX - _characterSize / 2,
              top: screenSize.height / 2 + _characterY - _characterSize / 2,
              width: _characterSize,
              height: _characterSize,
              child: Stack(
                children: [
                  // Character
                  Container(
                    width: _characterSize,
                    height: _characterSize,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        color: Colors.black,
                        size: 36,
                      ),
                    ),
                  ),

                  // Gun as a simple line
                  CustomPaint(
                    size: Size(_characterSize, _characterSize),
                    painter: GunPainter(
                      angle: _gunDirection,
                      length: 40,
                    ),
                  ),
                ],
              ),
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

            // Info panel
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Gun: ${(_gunDirection * 180 / math.pi).toStringAsFixed(1)}°',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final endPoint = center + Offset(
      math.cos(angle) * length,
      math.sin(angle) * length,
    );

    canvas.drawLine(center, endPoint, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}