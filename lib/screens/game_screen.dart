import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../widgets/character_sprite.dart';
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

  // Character size
  final double _characterSize = 100.0;

  // Movement speed
  final double _movementSpeed = 5.0;

  // Animation controllers
  late AnimationController _walkAnimController;
  late AnimationController _fireAnimController;
  late AnimationController _reloadAnimController;
  bool _isWalking = false;
  bool _isFiring = false;
  bool _isReloading = false;

  // Ammo state
  int _currentAmmo = 30;
  final int _maxAmmo = 30;
  bool _needsReload = false;

  // Walking direction
  double _facingDirection = 0;

  // Joystick controls
  bool _movementJoystickActive = false;
  Offset _movementJoystickPosition = Offset.zero;
  Offset _movementJoystickDelta = Offset.zero;

  final double _joystickRadius = 60.0;
  final double _innerJoystickRadius = 25.0;

  // Current frame for walking animation
  int _currentWalkFrame = 0;
  final int _totalWalkFrames = 7; // Based on your sprite sheet with 7 frames

  // Current frame for firing animation
  int _currentFireFrame = 0;
  final int _totalFireFrames = 4; // Based on your shot sprite sheet with 4 frames

  // Current frame for reload animation
  int _currentReloadFrame = 0;
  final int _totalReloadFrames = 4; // Assuming 4 frames for reload animation

  // Movement direction
  double _moveDirectionX = 0.0;
  double _moveDirectionY = 0.0;

  // Images
  ui.Image? characterImage;
  ui.Image? fireImage;
  ui.Image? reloadImage;
  bool isCharacterImageLoaded = false;
  bool isFireImageLoaded = false;
  bool isReloadImageLoaded = false;

  // Obstacle positions
  final List<Rect> _obstacles = [];
  final List<Rect> _tents = [];
  final List<Rect> _decorations = [];

  // Map size (larger than screen)
  final double mapWidth = 2000.0;
  final double mapHeight = 1500.0;

  // Cooldown timers
  double _fireCooldown = 0.0;
  double _reloadCooldown = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for walking
    _walkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Adjust animation speed here
    );

    // Initialize animation controller for firing
    _fireAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), // Faster for firing
    );

    // Initialize animation controller for reloading
    _reloadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Slower for reloading
    );

    _walkAnimController.addListener(() {
      if (_isWalking) {
        setState(() {
          // Calculate current frame based on animation value
          _currentWalkFrame = (_walkAnimController.value * _totalWalkFrames).floor() % _totalWalkFrames;
        });
      }
    });

    _fireAnimController.addListener(() {
      if (_isFiring) {
        setState(() {
          // Calculate current frame based on animation value
          _currentFireFrame = (_fireAnimController.value * _totalFireFrames).floor() % _totalFireFrames;
        });
      }
    });

    _reloadAnimController.addListener(() {
      if (_isReloading) {
        setState(() {
          // Calculate current frame based on animation value
          _currentReloadFrame = (_reloadAnimController.value * _totalReloadFrames).floor() % _totalReloadFrames;
        });
      }
    });

    _walkAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _walkAnimController.reset();
        _walkAnimController.forward();
      }
    });

    _fireAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isFiring = false;
          _currentFireFrame = 0;
        });
      }
    });

    _reloadAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isReloading = false;
          _currentReloadFrame = 0;
          _currentAmmo = _maxAmmo;
          _needsReload = false;
        });
      }
    });

    // Create army camp obstacles and decorations
    _generateArmyCamp();

    // Load images
    _loadCharacterImage();
    _loadFireImage();
    _loadReloadImage();

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

  Future<void> _loadFireImage() async {
    try {
      // Load the shot sprite
      final ByteData data = await rootBundle.load('assets/images/Shot_1.png');
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode the image
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();

      setState(() {
        fireImage = frameInfo.image;
        isFireImageLoaded = true;
      });
    } catch (e) {
      print('Error loading fire image: $e');
    }
  }

  Future<void> _loadReloadImage() async {
    try {
      // Load the reload sprite
      final ByteData data = await rootBundle.load('assets/images/Recharge.png');
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode the image
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();

      setState(() {
        reloadImage = frameInfo.image;
        isReloadImageLoaded = true;
      });
    } catch (e) {
      print('Error loading reload image: $e');
    }
  }

  @override
  void dispose() {
    _walkAnimController.dispose();
    _fireAnimController.dispose();
    _reloadAnimController.dispose();
    super.dispose();
  }

  void _startGameLoop() {
    Future.doWhile(() async {
      // Update cooldowns
      if (_fireCooldown > 0) {
        _fireCooldown -= 0.016; // Roughly 16ms per frame
      }
      if (_reloadCooldown > 0) {
        _reloadCooldown -= 0.016;
      }

      // Update character position based on joystick input
      if (_movementJoystickActive && _movementJoystickDelta.distance > 10) {
        // Only start walking animation if not firing or reloading
        if (!_isWalking && !_isReloading && !_isFiring) {
          _isWalking = true;
          _walkAnimController.forward();
        }

        // Calculate potential new position
        double newX = _characterX + _moveDirectionX * _movementSpeed;
        double newY = _characterY + _moveDirectionY * _movementSpeed;

        // Check map boundaries (allow full map movement)
        newX = newX.clamp(-mapWidth/2, mapWidth/0.5);
        newY = newY.clamp(-mapHeight/2, mapHeight/0.5);

        // Create character rect for collision detection
        final characterRect = Rect.fromCenter(
          center: Offset(newX, newY),
          width: _characterSize * 0.6, // Make collision box smaller than visual character
          height: _characterSize * 0.6,
        );

        // Optional: Collision detection (currently commented out)
        bool collisionDetected = false;
        for (final obstacle in _obstacles) {
          final adjustedObstacle = Rect.fromLTWH(
            obstacle.left - mapWidth/2,
            obstacle.top - mapHeight/2,
            obstacle.width,
            obstacle.height,
          );

          // Uncomment if you want to add collision detection
          // if (characterRect.overlaps(adjustedObstacle)) {
          //   collisionDetected = true;
          //   break;
          // }
        }

        for (final tent in _tents) {
          final adjustedTent = Rect.fromLTWH(
            tent.left - mapWidth/2,
            tent.top - mapHeight/2,
            tent.width,
            tent.height,
          );

          // Uncomment if you want to add collision detection
          // if (characterRect.overlaps(adjustedTent)) {
          //   collisionDetected = true;
          //   break;
          // }
        }

        // Update position (no collision check for now)
        setState(() {
          _characterX = newX;
          _characterY = newY;
          // Update facing direction for the character
          _facingDirection = math.atan2(_moveDirectionY, _moveDirectionX);
        });
      } else if (_isWalking && !_isReloading && !_isFiring) {
        // Only stop walking animation if not firing or reloading
        _isWalking = false;
        _walkAnimController.stop();
        setState(() {
          _currentWalkFrame = 0; // Reset to idle pose
        });
      }

      // Resume walking animation after firing is complete (if still moving)
      if (!_isFiring && !_isReloading && _movementJoystickActive &&
          _movementJoystickDelta.distance > 10 && !_isWalking) {
        _isWalking = true;
        _walkAnimController.forward();
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

  // Handle fire button press
  void _handleFireButtonPressed() {
    // Check if we can fire (has ammo, not reloading, cooldown is over)
    if (_currentAmmo > 0 && !_isReloading && _fireCooldown <= 0) {
      setState(() {
        _isFiring = true;
        _currentAmmo--;
        _fireCooldown = 0.3; // 300ms cooldown between shots

        // Check if we need to reload after this shot
        if (_currentAmmo <= 0) {
          _needsReload = true;
        }

        // Stop the walking animation if it's running
        if (_isWalking) {
          _walkAnimController.stop();
        }
      });

      // Start fire animation
      _fireAnimController.reset();
      _fireAnimController.forward();

      // TODO: Add projectile or hit detection logic if needed
    } else if (_currentAmmo <= 0 && !_isReloading) {
      // Auto-reload if empty
      _handleReloadButtonPressed();
    }
  }

  // Handle reload button press
  void _handleReloadButtonPressed() {
    // Check if we can reload (not already reloading, not full ammo, cooldown is over)
    if (!_isReloading && _currentAmmo < _maxAmmo && _reloadCooldown <= 0) {
      setState(() {
        _isReloading = true;
        _reloadCooldown = 2.0; // 2 second cooldown before can reload again

        // Stop firing animation if it's running
        if (_isFiring) {
          _fireAnimController.stop();
          _isFiring = false;
        }

        // Stop the walking animation if it's running
        if (_isWalking) {
          _walkAnimController.stop();
        }
      });

      // Start reload animation
      _reloadAnimController.reset();
      _reloadAnimController.forward();
    }
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

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    bool isActive = false,
    bool isWarning = false,
    bool isDisabled = false,
  }) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: isDisabled
            ? const Color(0xFF344D25).withOpacity(0.2)
            : isWarning
            ? const Color(0xFFCD7F32).withOpacity(0.5)
            : isActive
            ? const Color(0xFF648C4C).withOpacity(0.7)
            : const Color(0xFF344D25).withOpacity(0.4),
        shape: BoxShape.circle,
        border: Border.all(
          color: isDisabled
              ? const Color(0xFF8BA87E).withOpacity(0.3)
              : isWarning
              ? const Color(0xFFCD7F32)
              : const Color(0xFF8BA87E),
          width: 2,
        ),
        boxShadow: isActive
            ? [
          BoxShadow(
            color: const Color(0xFF8BA87E).withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isDisabled
                ? const Color(0xFFD0D9CB).withOpacity(0.5)
                : const Color(0xFFD0D9CB),
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isDisabled
                  ? const Color(0xFFD0D9CB).withOpacity(0.5)
                  : const Color(0xFFD0D9CB),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmmoDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF344D25).withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _needsReload ? const Color(0xFFCD7F32) : const Color(0xFF8BA87E),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pending_actions,
            color: _needsReload ? const Color(0xFFCD7F32) : const Color(0xFFD0D9CB),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$_currentAmmo / $_maxAmmo',
            style: TextStyle(
              color: _needsReload ? const Color(0xFFCD7F32) : const Color(0xFFD0D9CB),
              fontSize: 16,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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

    // Determine which sprite to show based on action priority
    // Priority: Reloading > Firing > Walking
    Widget activeSprite;

    if (_isReloading && isReloadImageLoaded && reloadImage != null) {
      // Show reload animation
      activeSprite = CharacterSprite(
        image: reloadImage!,
        frameIndex: _currentReloadFrame,
        totalFrames: _totalReloadFrames,
        size: _characterSize,
        direction: _facingDirection,
      );
    } else if (_isFiring && isFireImageLoaded && fireImage != null) {
      // Show firing animation
      activeSprite = CharacterSprite(
        image: fireImage!,
        frameIndex: _currentFireFrame,
        totalFrames: _totalFireFrames,
        size: _characterSize,
        direction: _facingDirection,
      );
    } else {
      // Show walking/idle animation
      activeSprite = CharacterSprite(
        image: characterImage!,
        frameIndex: _currentWalkFrame,
        totalFrames: _totalWalkFrames,
        size: _characterSize,
        direction: _facingDirection,
      );
    }

    return SizedBox(
      width: _characterSize,
      height: _characterSize,
      child: activeSprite,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
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

          // Joystick detection area (left half of screen)
          Positioned(
            left: 0,
            top: 0,
            width: screenSize.width / 2,
            height: screenSize.height,
            child: GestureDetector(
              onPanStart: (details) {
                _handleMovementJoystickStart(details.localPosition);
              },
              onPanUpdate: (details) {
                _handleMovementJoystickUpdate(details.localPosition);
              },
              onPanEnd: (details) {
                _handleMovementJoystickEnd();
              },
              // Use a transparent container to detect gestures without affecting visuals
              child: Container(
                color: Colors.transparent,
              ),
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

          // Fire button (bottom right)
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTap: _isReloading || _currentAmmo <= 0 ? null : _handleFireButtonPressed,
              child: _buildActionButton(
                onPressed: _handleFireButtonPressed,
                icon: Icons.flash_on,
                label: 'FIRE',
                isActive: _isFiring,
                isDisabled: _isReloading || _currentAmmo <= 0,
              ),
            ),
          ),

          // Reload button (bottom right, above fire button)
          Positioned(
            right: 20,
            bottom: 120,
            child: GestureDetector(
              onTap: _isReloading || _currentAmmo >= _maxAmmo ? null : _handleReloadButtonPressed,
              child: _buildActionButton(
                onPressed: _handleReloadButtonPressed,
                icon: Icons.refresh,
                label: 'RELOAD',
                isActive: _isReloading,
                isWarning: _needsReload && !_isReloading,
                isDisabled: _isReloading || _currentAmmo >= _maxAmmo,
              ),
            ),
          ),

          // Ammo display
          Positioned(
            right: 110,
            bottom: 70,
            child: _buildAmmoDisplay(),
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
                      'POSITION: (${_characterX.toStringAsFixed(0)}, ${_characterY.toStringAsFixed(0)})',
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
    );
  }
}