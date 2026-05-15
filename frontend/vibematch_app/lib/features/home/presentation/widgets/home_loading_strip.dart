import 'package:flutter/material.dart';

class HomeLoadingStrip extends StatelessWidget {
  const HomeLoadingStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: LinearProgressIndicator(
        minHeight: 3,
        color: Color(0xFF12C7B7),
        backgroundColor: Color(0xFFECE2D8),
      ),
    );
  }
}
