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
                  _SettingsSection(
                    title: 'Modes',
                    children: [
                      _SettingsCard(
                        icon: Icons.favorite_rounded,
                        title: 'VibeSync',
                        iconColor: RoomColors.coral,
                        onTap: onVibeSyncTap,
                      ),
                      _SettingsCard(
                        icon: Icons.smart_display_rounded,
                        title: 'Watch Party',
                        iconColor: RoomColors.aqua,
                        onTap: onWatchPartyTap,
                      ),
                      _SettingsCard(
                        icon: Icons.sports_cricket_rounded,
                        title: 'Cricket Mode',
                        iconColor: const Color(0xFF139A5C),
                        onTap: onCricketModeTap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  _SettingsSection(
                    title: 'Room Settings',
                    children: [
                      _SettingsCard(icon: Icons.wallpaper_rounded, title: 'Background', onTap: onBackgroundTap),
                      _SettingsCard(icon: privacyMode.icon, title: 'Privacy', badge: privacyMode.shortLabel, onTap: onPrivacyTap),
                      _SettingsCard(icon: Icons.grid_view_rounded, title: 'Seats', onTap: onSeatLayoutTap),
                      _SettingsCard(icon: Icons.campaign_rounded, title: 'Notice', onTap: onAnnouncementTap),
                      _SettingsCard(icon: Icons.how_to_reg_rounded, title: 'Requests', badge: joinRequestCount > 0 ? '$joinRequestCount' : null, onTap: onJoinRequestsTap),
                      _SettingsCard(icon: Icons.auto_awesome_rounded, title: 'Effects', onTap: onEffectsTap),
                      _SettingsCard(icon: Icons.music_note_rounded, title: 'Music', onTap: onMusicTap),
                      _SettingsCard(icon: Icons.block_rounded, title: 'Blocked', onTap: onBlockedTap),
                      _SettingsCard(icon: Icons.report_gmailerrorred_rounded, title: 'Reports', onTap: onReportsTap),
                      _SettingsCard(icon: Icons.cleaning_services_rounded, title: 'Clear Chat', iconColor: RoomColors.coral, onTap: onClearChatTap),
                    ],
                  ),
                  const SizedBox(height: 11),
                  _SettingsSection(
                    title: 'Permissions',
                    children: [
                      _ToggleCard(title: 'Images', value: roomImagesEnabled, onChanged: onToggleRoomImages),
                      _ToggleCard(title: 'Guests', value: guestMessagesEnabled, onChanged: onToggleGuestMessages),
                      _ToggleCard(title: 'Apply only', value: applyOnlyModeEnabled, onChanged: onToggleApplyOnlyMode),
                      if (canCloseRoom)
                        _SettingsCard(icon: Icons.power_settings_new_rounded, title: 'Close', iconColor: RoomColors.coral, onTap: onCloseRoom),
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            title,
            style: const TextStyle(
              color: RoomColors.plum,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 7),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: children.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 48,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (context, index) => children[index],
        ),
      ],
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
