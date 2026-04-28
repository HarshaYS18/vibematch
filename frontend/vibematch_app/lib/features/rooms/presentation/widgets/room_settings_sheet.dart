import 'package:flutter/material.dart';

import '../live_room_models.dart';
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

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      _SettingsCard(icon: Icons.wallpaper_rounded, title: 'Background', onTap: onBackgroundTap),
      _SettingsCard(icon: privacyMode.icon, title: 'Privacy', badge: privacyMode.shortLabel, onTap: onPrivacyTap),
      _SettingsCard(icon: Icons.grid_view_rounded, title: 'Seats', onTap: onSeatLayoutTap),
      _SettingsCard(icon: Icons.campaign_rounded, title: 'Notice', onTap: onAnnouncementTap),
      _SettingsCard(icon: Icons.how_to_reg_rounded, title: 'Requests', badge: joinRequestCount > 0 ? '$joinRequestCount' : null, onTap: onJoinRequestsTap),
      _SettingsCard(icon: Icons.auto_awesome_rounded, title: 'Effects', onTap: onEffectsTap),
      _SettingsCard(icon: Icons.music_note_rounded, title: 'Music', onTap: onMusicTap),
      _ToggleCard(title: 'Images', value: roomImagesEnabled, onChanged: onToggleRoomImages),
      _ToggleCard(title: 'Guests', value: guestMessagesEnabled, onChanged: onToggleGuestMessages),
      _ToggleCard(title: 'Apply only', value: applyOnlyModeEnabled, onChanged: onToggleApplyOnlyMode),
      _SettingsCard(icon: Icons.block_rounded, title: 'Blocked', onTap: onBlockedTap),
      _SettingsCard(icon: Icons.report_gmailerrorred_rounded, title: 'Reports', onTap: onReportsTap),
      _SettingsCard(icon: Icons.power_settings_new_rounded, title: 'Close', iconColor: RoomColors.coral, onTap: onCloseRoom),
    ];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.36,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, 7, 10, MediaQuery.paddingOf(context).bottom + 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            const SizedBox(height: 7),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 48,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                ),
                itemBuilder: (context, index) => items[index],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.badge,
    this.iconColor = RoomColors.aqua,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? badge;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFE8DDCF)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: RoomColors.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: RoomColors.gold,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF6),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8DDCF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: RoomColors.plum,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 36,
              height: 20,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? RoomColors.aqua : const Color(0xFFD8D0CA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
