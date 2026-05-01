import 'package:flutter/material.dart';

import 'vibes_ui_helpers.dart';

class VibesHeader extends StatelessWidget {
  const VibesHeader({
    super.key,
    required this.onCreateTap,
  });

  final VoidCallback onCreateTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Vibes',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
          ),
          VibesRoundIconButton(
            icon: Icons.add_rounded,
            onTap: onCreateTap,
          ),
        ],
      ),
    );
  }
}
