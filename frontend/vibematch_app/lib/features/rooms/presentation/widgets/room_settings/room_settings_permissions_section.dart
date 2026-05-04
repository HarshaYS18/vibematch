import 'package:flutter/material.dart';

import '../room_settings_components.dart';
import '../room_theme.dart';

class RoomSettingsPermissionsSection extends StatelessWidget {
  const RoomSettingsPermissionsSection({
    super.key,
    required this.roomImagesEnabled,
    required this.guestMessagesEnabled,
    required this.applyOnlyModeEnabled,
    required this.onToggleRoomImages,
    required this.onToggleGuestMessages,
    required this.onToggleApplyOnlyMode,
    required this.onCloseRoom,
    required this.canCloseRoom,
  });

  final bool roomImagesEnabled;
  final bool guestMessagesEnabled;
  final bool applyOnlyModeEnabled;
  final ValueChanged<bool> onToggleRoomImages;
  final ValueChanged<bool> onToggleGuestMessages;
  final ValueChanged<bool> onToggleApplyOnlyMode;
  final VoidCallback onCloseRoom;
  final bool canCloseRoom;

  @override
  Widget build(BuildContext context) {
    return RoomSettingsSection(
      title: 'Permissions',
      children: [
        RoomSettingsToggleCard(title: 'Images', value: roomImagesEnabled, onChanged: onToggleRoomImages),
        RoomSettingsToggleCard(title: 'Guests', value: guestMessagesEnabled, onChanged: onToggleGuestMessages),
        RoomSettingsToggleCard(title: 'Apply only', value: applyOnlyModeEnabled, onChanged: onToggleApplyOnlyMode),
        if (canCloseRoom)
          RoomSettingsCard(icon: Icons.power_settings_new_rounded, title: 'Close', iconColor: RoomColors.coral, onTap: onCloseRoom),
      ],
    );
  }
}
