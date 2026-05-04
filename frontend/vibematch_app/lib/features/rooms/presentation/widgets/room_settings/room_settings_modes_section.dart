import 'package:flutter/material.dart';

import '../room_settings_components.dart';
import '../room_theme.dart';

class RoomSettingsModesSection extends StatelessWidget {
  const RoomSettingsModesSection({
    super.key,
    required this.onVibeSyncTap,
    required this.onWatchPartyTap,
    required this.onCricketModeTap,
  });

  final VoidCallback onVibeSyncTap;
  final VoidCallback onWatchPartyTap;
  final VoidCallback onCricketModeTap;

  @override
  Widget build(BuildContext context) {
    return RoomSettingsSection(
      title: 'Modes',
      children: [
        RoomSettingsCard(
          icon: Icons.favorite_rounded,
          title: 'VibeSync',
          iconColor: RoomColors.coral,
          onTap: onVibeSyncTap,
        ),
        RoomSettingsCard(
          icon: Icons.smart_display_rounded,
          title: 'Watch Party',
          iconColor: RoomColors.aqua,
          onTap: onWatchPartyTap,
        ),
        RoomSettingsCard(
          icon: Icons.sports_cricket_rounded,
          title: 'Cricket Mode',
          iconColor: const Color(0xFF139A5C),
          onTap: onCricketModeTap,
        ),
      ],
    );
  }
}
