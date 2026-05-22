import 'package:flutter/material.dart';

import '../room_settings_components.dart';
import '../room_theme.dart';

class RoomSettingsModesSection extends StatelessWidget {
  const RoomSettingsModesSection({
    super.key,
    required this.onVibeSyncTap,
    required this.onWatchPartyTap,
    required this.onCricketModeTap,
    this.cricketModeActive = false,
  });

  final VoidCallback onVibeSyncTap;
  final VoidCallback onWatchPartyTap;
  final VoidCallback onCricketModeTap;
  final bool cricketModeActive;

  @override
  Widget build(BuildContext context) {
    return RoomSettingsSection(
      title: cricketModeActive ? 'Modes locked during Cricket Mode' : 'Modes',
      children: [
        RoomSettingsCard(
          icon: Icons.favorite_rounded,
          title: 'VibeSync',
          iconColor: cricketModeActive ? Colors.grey : RoomColors.coral,
          onTap: cricketModeActive ? null : onVibeSyncTap,
        ),
        RoomSettingsCard(
          icon: Icons.smart_display_rounded,
          title: 'Watch Party',
          iconColor: cricketModeActive ? Colors.grey : RoomColors.aqua,
          onTap: cricketModeActive ? null : onWatchPartyTap,
        ),
        if (!cricketModeActive)
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