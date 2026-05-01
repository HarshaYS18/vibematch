import 'package:flutter/material.dart';

import 'vibes_ui_helpers.dart';

class VibesEmptyState extends StatelessWidget {
  const VibesEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(24),
        decoration: vibePanelDecoration(radius: 30),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF6D5DF6),
              size: 42,
            ),
            SizedBox(height: 12),
            Text(
              'No Vibes here yet',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try another filter or create a new Vibe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF7A6B86),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
