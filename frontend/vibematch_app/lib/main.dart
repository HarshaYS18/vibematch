import 'package:flutter/material.dart';

import 'features/auth/presentation/auth_gate.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

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
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12C7B7),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF7F1),
      ),
      builder: (context, child) {
        return _BottomPopupSilencer(child: child ?? const SizedBox.shrink());
      },
      home: const AuthGate(),
    );
  }
}

class _BottomPopupSilencer extends StatefulWidget {
  const _BottomPopupSilencer({required this.child});

  final Widget child;

  @override
  State<_BottomPopupSilencer> createState() => _BottomPopupSilencerState();
}

class _BottomPopupSilencerState extends State<_BottomPopupSilencer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      final messenger = rootScaffoldMessengerKey.currentState;
      messenger?.clearSnackBars();
      messenger?.clearMaterialBanners();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
