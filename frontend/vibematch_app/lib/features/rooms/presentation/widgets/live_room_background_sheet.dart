import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomBackgroundSheet extends StatelessWidget {
  const LiveRoomBackgroundSheet({
    super.key,
    required this.currentTheme,
    required this.onThemeSelected,
    required this.onStoreTap,
  });

  final RoomBackgroundTheme currentTheme;
  final ValueChanged<RoomBackgroundTheme> onThemeSelected;
  final VoidCallback onStoreTap;

  @override
  Widget build(BuildContext context) {
    return RoomBackgroundPickerSheet(
      currentTheme: currentTheme,
      onThemeSelected: onThemeSelected,
      onStoreTap: onStoreTap,
    );
  }
}