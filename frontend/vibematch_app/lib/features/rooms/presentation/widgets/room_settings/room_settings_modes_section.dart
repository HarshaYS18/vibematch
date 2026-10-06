import 'package:flutter/material.dart';

import '../room_settings_components.dart';
import '../room_theme.dart';

class RoomSettingsModesSection extends StatelessWidget {
  const RoomSettingsModesSection({
    super.key,
    required this.onVibeSyncTap,
    required this.onWatchPartyTap,
    required this.onCricketModeTap,
    required this.onPkModeTap,
    this.cricketModeActive = false,
    this.pkModeEngaged = false,
  });

  final VoidCallback onVibeSyncTap;
  final VoidCallback onWatchPartyTap;
  final VoidCallback onCricketModeTap;
  final VoidCallback onPkModeTap;
  final bool cricketModeActive;
  final bool pkModeEngaged;

  @override
  Widget build(BuildContext context) {
    return RoomSettingsSection(
      title: cricketModeActive
          ? 'Modes locked during Cricket Mode'
          : pkModeEngaged
              ? 'Modes locked during Room PK'
              : 'Modes',
      children: [
        RoomSettingsCard(
          icon: Icons.favorite_rounded,
          title: (cricketModeActive || pkModeEngaged)
              ? 'VibeSync locked'
              : 'VibeSync',
          iconColor: (cricketModeActive || pkModeEngaged)
              ? Colors.grey
              : RoomColors.coral,
          onTap: (cricketModeActive || pkModeEngaged) ? () {} : onVibeSyncTap,
        ),
        RoomSettingsCard(
          icon: Icons.smart_display_rounded,
          title: (cricketModeActive || pkModeEngaged)
              ? 'Watch Party locked'
              : 'Watch Party',
          iconColor: (cricketModeActive || pkModeEngaged)
              ? Colors.grey
              : RoomColors.aqua,
          onTap: (cricketModeActive || pkModeEngaged) ? () {} : onWatchPartyTap,
        ),
        RoomSettingsCard(
          icon: Icons.flash_on_rounded,
          title: pkModeEngaged ? 'Room PK · Active' : 'Room PK',
          iconColor: RoomColors.coral,
          onTap: onPkModeTap,
        ),
        if (!cricketModeActive && !pkModeEngaged)
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