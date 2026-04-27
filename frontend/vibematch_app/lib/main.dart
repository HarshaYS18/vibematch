import 'package:flutter/material.dart';

import 'features/auth/presentation/auth_gate.dart';

void main() {
  runApp(const VibeMatchApp());
}

class VibeMatchApp extends StatelessWidget {
  const VibeMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vibe Match',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12C7B7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7F1),
      ),
      home: const AuthGate(),
    );
  }
}