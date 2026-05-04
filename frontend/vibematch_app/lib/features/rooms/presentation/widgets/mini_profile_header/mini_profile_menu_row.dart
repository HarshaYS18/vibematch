import 'package:flutter/material.dart';

import '../room_theme.dart';

class MiniProfileMenuRow extends StatelessWidget {
  const MiniProfileMenuRow({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 9),
        Text(
          label,
          style: const TextStyle(
            color: RoomColors.plum,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
