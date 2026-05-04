import 'package:flutter/material.dart';

import '../room_theme.dart';

class RoomSettingsSheetHeader extends StatelessWidget {
  const RoomSettingsSheetHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.settings_rounded, color: RoomColors.aqua, size: 18),
        SizedBox(width: 6),
        Text(
          'Room Settings',
          style: TextStyle(
            color: RoomColors.plum,
            fontSize: 15.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
