import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_settings_components.dart';
import '../room_theme.dart';

class RoomSettingsMainSection extends StatelessWidget {
  const RoomSettingsMainSection({
    super.key,
    required this.privacyMode,
    required this.joinRequestCount,
    required this.onBackgroundTap,
    required this.onPrivacyTap,
    required this.onSeatLayoutTap,
    required this.onJoinRequestsTap,
    required this.onAnnouncementTap,
    required this.onReportsTap,
    required this.onBlockedTap,
    required this.onEffectsTap,
    required this.onMusicTap,
    required this.onClearChatTap,
  });

  final RoomPrivacyMode privacyMode;
  final int joinRequestCount;
  final VoidCallback onBackgroundTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onSeatLayoutTap;
  final VoidCallback onJoinRequestsTap;
  final VoidCallback onAnnouncementTap;
  final VoidCallback onReportsTap;
  final VoidCallback onBlockedTap;
  final VoidCallback onEffectsTap;
  final VoidCallback onMusicTap;
  final VoidCallback onClearChatTap;

  @override
  Widget build(BuildContext context) {
    return RoomSettingsSection(
      title: 'Room Settings',
      children: [
        RoomSettingsCard(icon: Icons.wallpaper_rounded, title: 'Background', onTap: onBackgroundTap),
        RoomSettingsCard(icon: privacyMode.icon, title: 'Privacy', badge: privacyMode.shortLabel, onTap: onPrivacyTap),
        RoomSettingsCard(icon: Icons.grid_view_rounded, title: 'Seats', onTap: onSeatLayoutTap),
        RoomSettingsCard(icon: Icons.campaign_rounded, title: 'Notice', onTap: onAnnouncementTap),
        RoomSettingsCard(icon: Icons.how_to_reg_rounded, title: 'Requests', badge: joinRequestCount > 0 ? '$joinRequestCount' : null, onTap: onJoinRequestsTap),
        RoomSettingsCard(icon: Icons.auto_awesome_rounded, title: 'Effects', onTap: onEffectsTap),
        RoomSettingsCard(icon: Icons.music_note_rounded, title: 'Music', onTap: onMusicTap),
        RoomSettingsCard(icon: Icons.block_rounded, title: 'Blocked', onTap: onBlockedTap),
        RoomSettingsCard(icon: Icons.report_gmailerrorred_rounded, title: 'Reports', onTap: onReportsTap),
        RoomSettingsCard(icon: Icons.cleaning_services_rounded, title: 'Clear Chat', iconColor: RoomColors.coral, onTap: onClearChatTap),
      ],
    );
  }
}
