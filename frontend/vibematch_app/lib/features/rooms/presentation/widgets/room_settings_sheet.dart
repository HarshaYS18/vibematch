import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_settings_components.dart';
import 'room_theme.dart';

class RoomSettingsSheet extends StatelessWidget {
  const RoomSettingsSheet({
    super.key,
    required this.privacyMode,
    required this.roomImagesEnabled,
    required this.guestMessagesEnabled,
    required this.applyOnlyModeEnabled,
    required this.joinRequestCount,
    required this.onBackgroundTap,
    required this.onPrivacyTap,
    required this.onSeatLayoutTap,
    required this.onToggleRoomImages,
    required this.onToggleGuestMessages,
    required this.onToggleApplyOnlyMode,
    required this.onJoinRequestsTap,
    required this.onCloseRoom,
    required this.onAnnouncementTap,
    required this.onInboxTap,
    required this.onReportsTap,
    required this.onBlockedTap,
    required this.onEffectsTap,
    required this.onMusicTap,
    required this.onVibeSyncTap,
    required this.onWatchPartyTap,
    required this.onCricketModeTap,
    required this.onClearChatTap,
    required this.canCloseRoom,
  });

  final RoomPrivacyMode privacyMode;
  final bool roomImagesEnabled;
  final bool guestMessagesEnabled;
  final bool applyOnlyModeEnabled;
  final int joinRequestCount;
  final VoidCallback onBackgroundTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onSeatLayoutTap;
  final ValueChanged<bool> onToggleRoomImages;
  final ValueChanged<bool> onToggleGuestMessages;
  final ValueChanged<bool> onToggleApplyOnlyMode;
  final VoidCallback onJoinRequestsTap;
  final VoidCallback onCloseRoom;
  final VoidCallback onAnnouncementTap;
  final VoidCallback onInboxTap;
  final VoidCallback onReportsTap;
  final VoidCallback onBlockedTap;
  final VoidCallback onEffectsTap;
  final VoidCallback onMusicTap;
  final VoidCallback onVibeSyncTap;
  final VoidCallback onWatchPartyTap;
  final VoidCallback onCricketModeTap;
  final VoidCallback onClearChatTap;
  final bool canCloseRoom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.52,
      child: Container(
        padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.paddingOf(context).bottom + 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(width: 42),
            const SizedBox(height: 6),
            const Row(
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
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  RoomSettingsSection(
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
                  ),
                  const SizedBox(height: 11),
                  RoomSettingsSection(
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
                  ),
                  const SizedBox(height: 11),
                  RoomSettingsSection(
                    title: 'Permissions',
                    children: [
                      RoomSettingsToggleCard(title: 'Images', value: roomImagesEnabled, onChanged: onToggleRoomImages),
                      RoomSettingsToggleCard(title: 'Guests', value: guestMessagesEnabled, onChanged: onToggleGuestMessages),
                      RoomSettingsToggleCard(title: 'Apply only', value: applyOnlyModeEnabled, onChanged: onToggleApplyOnlyMode),
                      if (canCloseRoom)
                        RoomSettingsCard(icon: Icons.power_settings_new_rounded, title: 'Close', iconColor: RoomColors.coral, onTap: onCloseRoom),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
