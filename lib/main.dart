import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:project_x/screens/game_screen.dart';

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

