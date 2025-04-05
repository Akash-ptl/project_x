// Fixed version of game_screen.dart with sprite and grenade improvements

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
  late AnimationController _grenadeThrowAnimController;
  late AnimationController _grenadeBlastAnimController;
  bool _isWalking = false;
  bool _isFiring = false;
  bool _isReloading = false;
  bool _isThrowing = false;
  bool _isBlasting = false;
  bool _fireButtonHeld = false;

  // Ammo state
  int _currentAmmo = 30;
  final int _maxAmmo = 30;
  bool _needsReload = false;
  int _grenadeCount = 3;
  final int _maxGrenades = 3;

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
  final int _totalFireFrames = 13; // Updated to 13 frames based on new sprite sheet

  // Current frame for reload animation
  int _currentReloadFrame = 0;
  final int _totalReloadFrames = 4; // Assuming 4 frames for reload animation

  // Current frame for grenade throw animation
  int _currentGrenadeThrowFrame = 0;
  final int _totalGrenadeThrowFrames = 9; // Adjust based on your sprite sheet

  // Current frame for grenade blast animation
  int _currentGrenadeBlastFrame = 0;
  final int _totalGrenadeBlastFrames = 5; // Adjust based on your sprite sheet

  // Movement direction
  double _moveDirectionX = 0.0;
  double _moveDirectionY = 0.0;

  // Images
  ui.Image? characterImage;
  ui.Image? fireImage;
  ui.Image? reloadImage;
  ui.Image? grenadeThrowImage;
  ui.Image? grenadeBlastImage;
  bool isCharacterImageLoaded = false;
  bool isFireImageLoaded = false;
  bool isReloadImageLoaded = false;
  bool isGrenadeThrowImageLoaded = false;
  bool isGrenadeBlastImageLoaded = false;

  // Obstacle positions
  final List<Rect> _obstacles = [];
  final List<Rect> _tents = [];
  final List<Rect> _decorations = [];

  // Map size (larger than screen)
  final double mapWidth = 2000.0;
  final double mapHeight = 1500.0;

  // Screen size
  late Size screenSize;

  // Cooldown timers
  double _fireCooldown = 0.0;
  double _reloadCooldown = 0.0;
  double _grenadeCooldown = 0.0;

  // Grenade state variables
  Offset? _activeGrenadePosition;
  double? _activeGrenadeThrowTime;
  double _grenadeFlightDuration = 1.0; // Time in seconds for grenade to reach target

  // Added for grenade trajectory
  Offset? _grenadeStartPosition;
  Offset? _grenadeTargetPosition;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for walking
    _walkAnimController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 600,
      ), // Adjust animation speed here
    );

    // Initialize animation controller for firing
    _fireAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Adjusted for 13 frames
    );

    // Initialize animation controller for reloading
    _reloadAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Slower for reloading
    );

    // Initialize animation controller for grenade throw
    _grenadeThrowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900), // Adjust for throw animation
    );

    // Initialize animation controller for grenade blast
    _grenadeBlastAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500), // Quick blast animation
    );

    _walkAnimController.addListener(() {
      if (_isWalking) {
        setState(() {
          // Calculate current frame based on animation value
          _currentWalkFrame =
              (_walkAnimController.value * _totalWalkFrames).floor() %
                  _totalWalkFrames;
        });
      }
    });

    _fireAnimController.addListener(() {
      if (_isFiring) {
        setState(() {
          // Calculate current frame based on animation value
          _currentFireFrame =
              (_fireAnimController.value * _totalFireFrames).floor() %
                  _totalFireFrames;
        });
      }
    });

    _reloadAnimController.addListener(() {
      if (_isReloading) {
        setState(() {
          // Calculate current frame based on animation value
          _currentReloadFrame =
              (_reloadAnimController.value * _totalReloadFrames).floor() %
                  _totalReloadFrames;
        });
      }
    });

    _grenadeThrowAnimController.addListener(() {
      if (_isThrowing) {
        setState(() {
          // Calculate current frame based on animation value
          _currentGrenadeThrowFrame =
              (_grenadeThrowAnimController.value * _totalGrenadeThrowFrames)
                  .floor() %
                  _totalGrenadeThrowFrames;
        });
      }
    });

    _grenadeBlastAnimController.addListener(() {
      if (_isBlasting) {
        setState(() {
          // Calculate current frame based on animation value
          _currentGrenadeBlastFrame =
              (_grenadeBlastAnimController.value * _totalGrenadeBlastFrames)
                  .floor() %
                  _totalGrenadeBlastFrames;
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
        if (_fireButtonHeld && _currentAmmo > 0 && !_isReloading) {
          // If fire button is still held and we have ammo, continue firing
          _fireAnimController.reset();
          _fireAnimController.forward();

          setState(() {
            _currentAmmo--;
            if (_currentAmmo <= 0) {
              _needsReload = true;
              _fireButtonHeld = false; // Stop automatic fire when out of ammo
            }
          });
        } else {
          setState(() {
            _isFiring = false;
            _currentFireFrame = 0;
          });
        }
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

    _grenadeThrowAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isThrowing = false;
          _currentGrenadeThrowFrame = 0;
        });
      }
    });

    _grenadeBlastAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isBlasting = false;
          _currentGrenadeBlastFrame = 0;
          _activeGrenadePosition = null;
          _grenadeStartPosition = null;
          _grenadeTargetPosition = null;
        });
      }
    });

    // Create army camp obstacles and decorations
    _generateArmyCamp();

    // Load images
    _loadCharacterImage();
    _loadFireImage();
    _loadReloadImage();
    _loadGrenadeThrowImage();
    _loadGrenadeBlastImage();

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
      if ((x - mapWidth / 2).abs() < 200 && (y - mapHeight / 2).abs() < 200) {
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
      if ((x - mapWidth / 2).abs() < 150 && (y - mapHeight / 2).abs() < 150) {
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
    _grenadeThrowAnimController.dispose();
    _grenadeBlastAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadGrenadeThrowImage() async {
    try {
      // Corrected - using correct images for throw animation
      final ByteData data = await rootBundle.load(
        'assets/images/Grenade.png',
      );
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode the image
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();

      setState(() {
        grenadeThrowImage = frameInfo.image;
        isGrenadeThrowImageLoaded = true;
      });
    } catch (e) {
      print('Error loading grenade throw image: $e');
    }
  }

  Future<void> _loadGrenadeBlastImage() async {
    try {
      // Corrected - using correct images for blast animation
      final ByteData data = await rootBundle.load('assets/images/Explosion.png');
      final Uint8List bytes = data.buffer.asUint8List();

      // Decode the image
      final codec = await ui.instantiateImageCodec(bytes);
      final frameInfo = await codec.getNextFrame();

      setState(() {
        grenadeBlastImage = frameInfo.image;
        isGrenadeBlastImageLoaded = true;
      });
    } catch (e) {
      print('Error loading grenade blast image: $e');
    }
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
      if (_grenadeCooldown > 0) {
        _grenadeCooldown -= 0.016;
      }

      // Update grenade flight time if there's an active grenade
      if (_grenadeStartPosition != null &&
          _grenadeTargetPosition != null &&
          _activeGrenadeThrowTime != null &&
          !_isBlasting) {

        _activeGrenadeThrowTime = _activeGrenadeThrowTime! + 0.016;

        // Calculate current grenade position based on flight time
        final progress = math.min(_activeGrenadeThrowTime! / _grenadeFlightDuration, 1.0);

        // Apply a simple arc trajectory
        final dx = _grenadeTargetPosition!.dx - _grenadeStartPosition!.dx;
        final dy = _grenadeTargetPosition!.dy - _grenadeStartPosition!.dy;

        // Add a vertical arc
        final arcHeight = math.sqrt(dx * dx + dy * dy) * 0.5; // Max height of arc
        final verticalOffset = math.sin(progress * math.pi) * arcHeight;

        final currentX = _grenadeStartPosition!.dx + dx * progress;
        final currentY = _grenadeStartPosition!.dy + dy * progress - verticalOffset;

        setState(() {
          _activeGrenadePosition = Offset(currentX, currentY);
        });

        // Check if grenade has reached its target
        if (progress >= 1.0 && !_isBlasting) {
          // Start blast animation after grenade reaches target
          setState(() {
            _activeGrenadePosition = _grenadeTargetPosition;
            _isBlasting = true;
            _grenadeBlastAnimController.reset();
            _grenadeBlastAnimController.forward();
          });
        }
      }

      // Update character position based on joystick input
      if (_movementJoystickActive && _movementJoystickDelta.distance > 10) {
        // Only start walking animation if not firing, reloading, or throwing
        if (!_isWalking &&
            !_isReloading &&
            !_isFiring &&
            !_isThrowing &&
            !_isBlasting) {
          _isWalking = true;
          _walkAnimController.forward();
        }

        // Calculate potential new position
        double newX = _characterX + _moveDirectionX * _movementSpeed;
        double newY = _characterY + _moveDirectionY * _movementSpeed;

        // Check map boundaries (allow full map movement)
        newX = newX.clamp(-mapWidth / 2, mapWidth / 2);
        newY = newY.clamp(-mapHeight / 2, mapHeight / 2);

        // Create character rect for collision detection
        final characterRect = Rect.fromCenter(
          center: Offset(newX, newY),
          width: _characterSize * 0.6,
          // Make collision box smaller than visual character
          height: _characterSize * 0.6,
        );

        // Update position
        setState(() {
          _characterX = newX;
          _characterY = newY;
          // Update facing direction for the character
          _facingDirection = math.atan2(_moveDirectionY, _moveDirectionX);
        });
      } else if (_isWalking &&
          !_isReloading &&
          !_isFiring &&
          !_isThrowing &&
          !_isBlasting) {
        // Only stop walking animation if not firing, reloading, or throwing grenades
        _isWalking = false;
        _walkAnimController.stop();
        setState(() {
          _currentWalkFrame = 0; // Reset to idle pose
        });
      }

      // Resume walking animation after actions are complete (if still moving)
      if (!_isFiring &&
          !_isReloading &&
          !_isThrowing &&
          !_isBlasting &&
          _movementJoystickActive &&
          _movementJoystickDelta.distance > 10 &&
          !_isWalking) {
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
    if (_currentAmmo > 0 &&
        !_isReloading &&
        !_isThrowing &&
        _fireCooldown <= 0) {
      setState(() {
        _isFiring = true;
        _fireButtonHeld = true;
        _currentAmmo--;
        _fireCooldown =
        0.1; // 100ms cooldown between shots (faster for continuous fire)

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
    } else if (_currentAmmo <= 0 && !_isReloading && !_isThrowing) {
      // Auto-reload if empty
      _handleReloadButtonPressed();
    }
  }

  // Handle fire button release
  void _handleFireButtonReleased() {
    _fireButtonHeld = false;
  }

  // Handle reload button press
  void _handleReloadButtonPressed() {
    // Check if we can reload (not already reloading, not full ammo, cooldown is over)
    if (!_isReloading &&
        !_isThrowing &&
        _currentAmmo < _maxAmmo &&
        _reloadCooldown <= 0) {
      setState(() {
        _isReloading = true;
        _reloadCooldown = 2.0; // 2 second cooldown before can reload again
        _fireButtonHeld = false; // Stop automatic fire when reloading

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

  // Handle grenade button press
  void _handleGrenadeButtonPressed() {
    // Check if we can throw a grenade (has grenades, not reloading, not firing, cooldown is over)
    if (_grenadeCount > 0 &&
        !_isReloading &&
        !_isFiring &&
        !_isThrowing &&
        _grenadeCooldown <= 0) {
      setState(() {
        _isThrowing = true;
        _grenadeCount--;
        _grenadeCooldown = 3.0; // 3 second cooldown between grenade throws

        // Set starting position as player's position
        _grenadeStartPosition = Offset(_characterX, _characterY);

        // Calculate target position based on facing direction (farther away)
        final targetX = _characterX + math.cos(_facingDirection) * 300;
        final targetY = _characterY + math.sin(_facingDirection) * 300;
        _grenadeTargetPosition = Offset(targetX, targetY);

        // Initialize active position to starting position
        _activeGrenadePosition = _grenadeStartPosition;
        _activeGrenadeThrowTime = 0.0;

        // Stop the walking animation if it's running
        if (_isWalking) {
          _walkAnimController.stop();
        }

        // Stop firing if it's happening
        if (_isFiring) {
          _fireAnimController.stop();
          _isFiring = false;
          _fireButtonHeld = false;
        }
      });

      // Start grenade throw animation
      _grenadeThrowAnimController.reset();
      _grenadeThrowAnimController.forward();
    }
  }

  Widget _buildJoystick(Offset delta) {
    return Container(
      width: _joystickRadius * 2,
      height: _joystickRadius * 2,
      decoration: BoxDecoration(
        color: const Color(0xFF344D25).withOpacity(0.2),
        // Military green with transparency
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
        color:
        isDisabled
            ? const Color(0xFF344D25).withOpacity(0.2)
            : isWarning
            ? const Color(0xFFCD7F32).withOpacity(0.5)
            : isActive
            ? const Color(0xFF648C4C).withOpacity(0.7)
            : const Color(0xFF344D25).withOpacity(0.4),
        shape: BoxShape.circle,
        border: Border.all(
          color:
          isDisabled
              ? const Color(0xFF8BA87E).withOpacity(0.3)
              : isWarning
              ? const Color(0xFFCD7F32)
              : const Color(0xFF8BA87E),
          width: 2,
        ),
        boxShadow:
        isActive
            ? [
          BoxShadow(
            color: const Color(0xFF8BA87E).withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color:
            isDisabled
                ? const Color(0xFFD0D9CB).withOpacity(0.5)
                : const Color(0xFFD0D9CB),
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color:
              isDisabled
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
          color:
          _needsReload ? const Color(0xFFCD7F32) : const Color(0xFF8BA87E),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.pending_actions,
            color:
            _needsReload
                ? const Color(0xFFCD7F32)
                : const Color(0xFFD0D9CB),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$_currentAmmo / $_maxAmmo',
            style: TextStyle(
              color:
              _needsReload
                  ? const Color(0xFFCD7F32)
                  : const Color(0xFFD0D9CB),
              fontSize: 16,
              fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrenadeDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF344D25).withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _grenadeCount == 0
              ? const Color(0xFFCD7F32)
              : const Color(0xFF8BA87E),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sports_handball,
            color: _grenadeCount == 0
                ? const Color(0xFFCD7F32)
                : const Color(0xFFD0D9CB),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$_grenadeCount / $_maxGrenades',
            style: TextStyle(
              color: _grenadeCount == 0
                  ? const Color(0xFFCD7F32)
                  : const Color(0xFFD0D9CB),
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
        color: const Color(0xFF344D25).withOpacity(0.2),
        // Military green with transparency
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
          child: Text("Loading...", style: TextStyle(color: Colors.black)),
        ),
      );
    }

    // Determine which sprite to show based on action priority
    // Priority: Grenade Throw > Reloading > Firing > Walking
    Widget activeSprite;

    if (_isThrowing && isGrenadeThrowImageLoaded && grenadeThrowImage != null) {
      // Show grenade throw animation
      activeSprite = CharacterSprite(
        image: grenadeThrowImage!,
        frameIndex: _currentGrenadeThrowFrame,
        totalFrames: _totalGrenadeThrowFrames,
        size: _characterSize,
        direction: _facingDirection,
      );
    } else if (_isReloading && isReloadImageLoaded && reloadImage != null) {
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
      child: Stack(
        children: [
          // Main character sprite
          activeSprite,
        ],
      ),
    );
  }

  // Display a flying grenade during its trajectory
  Widget _buildFlyingGrenade() {
    if (_activeGrenadePosition == null ||
        !isGrenadeThrowImageLoaded ||
        grenadeThrowImage == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      // Transform world coordinates to screen coordinates
      left: (screenSize.width / 2) + (_activeGrenadePosition!.dx - _characterX) - _characterSize / 4,
      top: (screenSize.height / 2) + (_activeGrenadePosition!.dy - _characterY) - _characterSize / 4,
      child: SizedBox(
        width: _characterSize / 2,
        height: _characterSize / 2,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFCD7F32),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  // Display a grenade blast at the target location
  Widget _buildGrenadeBlast() {
    if (!_isBlasting ||
        _activeGrenadePosition == null ||
        !isGrenadeBlastImageLoaded ||
        grenadeBlastImage == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      // Transform world coordinates to screen coordinates
      left: (screenSize.width / 2) + (_activeGrenadePosition!.dx - _characterX) - _characterSize / 2,
      top: (screenSize.height / 2) + (_activeGrenadePosition!.dy - _characterY) - _characterSize / 2,
      child: SizedBox(
        width: _characterSize,
        height: _characterSize,
        child: CharacterSprite(
          image: grenadeBlastImage!,
          frameIndex: _currentGrenadeBlastFrame,
          totalFrames: _totalGrenadeBlastFrames,
          size: _characterSize,
          direction: 0, // No direction for blast
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    screenSize = MediaQuery.of(context).size;

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
              child: Container(color: Colors.transparent),
            ),
          ),

          // Flying grenade visualization
          _buildFlyingGrenade(),

          // Grenade blast effect
          _buildGrenadeBlast(),

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
          // Grenade button (bottom right, above reload button)
          Positioned(
            right: 20,
            bottom: 220,
            child: GestureDetector(
              onTap:
              _isReloading || _isFiring || _isThrowing || _grenadeCount <= 0
                  ? null
                  : _handleGrenadeButtonPressed,
              child: _buildActionButton(
                onPressed: _handleGrenadeButtonPressed,
                icon: Icons.sports_handball,
                label: 'GRENADE',
                isActive: _isThrowing,
                isWarning: _grenadeCount == 1 && !_isThrowing,
                // Highlight when only one grenade left
                isDisabled:
                _isReloading ||
                    _isFiring ||
                    _isThrowing ||
                    _grenadeCount <= 0,
              ),
            ),
          ),
          // Fire button (bottom right)
          Positioned(
            right: 20,
            bottom: 20,
            child: GestureDetector(
              onTapDown: (_) {
                if (!_isReloading && _currentAmmo > 0) {
                  _handleFireButtonPressed();
                }
              },
              onTapUp: (_) {
                _handleFireButtonReleased();
              },
              onTapCancel: () {
                _handleFireButtonReleased();
              },
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
              onTap:
              _isReloading || _currentAmmo >= _maxAmmo
                  ? null
                  : _handleReloadButtonPressed,
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
          Positioned(right: 110, bottom: 70, child: _buildAmmoDisplay()),

          // Grenade count display
          Positioned(right: 110, bottom: 110, child: _buildGrenadeDisplay()),

          // HUD Info panel
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF344D25).withOpacity(0.5),
                  // Military green with transparency
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
                border: Border.all(color: const Color(0xFF8BA87E), width: 2),
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