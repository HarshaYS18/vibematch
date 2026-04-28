import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_settings_sheet.dart';

class LiveRoomPrivacySheet extends StatelessWidget {
  const LiveRoomPrivacySheet({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final RoomPrivacyMode currentMode;
  final ValueChanged<RoomPrivacyMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return PrivacySettingsSheet(
      currentMode: currentMode,
      onModeChanged: onModeChanged,
    );
  }
}