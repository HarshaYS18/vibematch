import 'package:flutter/material.dart';

import 'features/audio_mediasoup/presentation/mediasoup_audio_test_page.dart';

void main() {
  runApp(const VibeMatchMediasoupTestApp());
}

class VibeMatchMediasoupTestApp extends StatelessWidget {
  const VibeMatchMediasoupTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VibeMatch mediasoup Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF12C7B7),
          brightness: Brightness.dark,
        ),
      ),
      home: const MediasoupAudioTestPage(),
    );
  }
}
