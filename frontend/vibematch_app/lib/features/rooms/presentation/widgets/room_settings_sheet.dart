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
    required this.isVibeSyncActive,
    required this.joinRequestCount,
    required this.onBackgroundTap,
    required this.onPrivacyTap,
    required this.onSeatLayoutTap,
    required this.onAdminsTap,
    required this.onVibeSyncTap,
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
  final bool isVibeSyncActive;
  final int joinRequestCount;
  final VoidCallback onBackgroundTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onSeatLayoutTap;
  final VoidCallback onAdminsTap;
  final VoidCallback onVibeSyncTap;
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
      _SettingsCard(
        icon: Icons.wallpaper_rounded,
        title: 'Background',
        onTap: onBackgroundTap,
      ),
      _SettingsCard(
        icon: privacyMode.icon,
        title: 'Privacy',
        badge: privacyMode.shortLabel,
        onTap: onPrivacyTap,
      ),
      _SettingsCard(
        icon: Icons.grid_view_rounded,
        title: 'Seats',
        onTap: onSeatLayoutTap,
      ),
      _SettingsCard(
        icon: Icons.campaign_rounded,
        title: 'Notice',
        onTap: onAnnouncementTap,
      ),
      _SettingsCard(
        icon: Icons.favorite_rounded,
        title: 'VibeSync',
        badge: isVibeSyncActive ? 'Live' : null,
        iconColor: RoomColors.coral,
        onTap: onVibeSyncTap,
      ),
      _SettingsCard(
        icon: Icons.shield_rounded,
        title: 'Admins',
        onTap: onAdminsTap,
      ),
      _SettingsCard(
        icon: Icons.how_to_reg_rounded,
        title: 'Requests',
        badge: joinRequestCount > 0 ? '$joinRequestCount' : null,
        onTap: onJoinRequestsTap,
      ),
      _SettingsCard(
        icon: Icons.inbox_rounded,
        title: 'Inbox',
        onTap: onInboxTap,
      ),
      _SettingsCard(
        icon: Icons.auto_awesome_rounded,
        title: 'Effects',
        onTap: onEffectsTap,
      ),
      _SettingsCard(
        icon: Icons.music_note_rounded,
        title: 'Music',
        onTap: onMusicTap,
      ),
      _ToggleCard(
        title: 'Images',
        value: roomImagesEnabled,
        onChanged: onToggleRoomImages,
      ),
      _ToggleCard(
        title: 'Guests',
        value: guestMessagesEnabled,
        onChanged: onToggleGuestMessages,
      ),
      _ToggleCard(
        title: 'Apply only',
        value: applyOnlyModeEnabled,
        onChanged: onToggleApplyOnlyMode,
      ),
      _SettingsCard(
        icon: Icons.block_rounded,
        title: 'Blocked',
        onTap: onBlockedTap,
      ),
      _SettingsCard(
        icon: Icons.report_gmailerrorred_rounded,
        title: 'Reports',
        onTap: onReportsTap,
      ),
      _SettingsCard(
        icon: Icons.power_settings_new_rounded,
        title: 'Close',
        iconColor: RoomColors.coral,
        onTap: onCloseRoom,
      ),
    ];

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.34,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          10,
          7,
          10,
          MediaQuery.paddingOf(context).bottom + 8,
        ),
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

class PrivacySettingsSheet extends StatefulWidget {
  const PrivacySettingsSheet({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final RoomPrivacyMode currentMode;
  final ValueChanged<RoomPrivacyMode> onModeChanged;

  @override
  State<PrivacySettingsSheet> createState() => _PrivacySettingsSheetState();
}

class _PrivacySettingsSheetState extends State<PrivacySettingsSheet> {
  late RoomPrivacyMode _mode;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _mode = widget.currentMode;
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.42,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            MediaQuery.paddingOf(context).bottom + 10,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SheetHandle(width: 42),
              const SizedBox(height: 8),
              const Text(
                'Password & Privacy',
                style: TextStyle(
                  color: RoomColors.plum,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    ...RoomPrivacyMode.values.map((mode) {
                      return _PrivacyTile(
                        mode: mode,
                        selected: _mode == mode,
                        onTap: () {
                          setState(() => _mode = mode);
                          widget.onModeChanged(mode);
                        },
                      );
                    }),
                    if (_mode == RoomPrivacyMode.locked) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          hintText: 'Set room lock password',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFFAF7F1),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => RoomToast.show(
                            context,
                            _passwordController.text.trim().isEmpty
                                ? 'Enter a lock password'
                                : 'Room lock saved',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: RoomColors.plum,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                          child: const Text(
                            'Save lock',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final RoomPrivacyMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RoomColors.aqua.withValues(alpha: 0.12)
              : const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? RoomColors.aqua.withValues(alpha: 0.30)
                : const Color(0xFFE8DDCF),
          ),
        ),
        child: Row(
          children: [
            Icon(
              mode.icon,
              color: selected ? RoomColors.aqua : RoomColors.plum,
              size: 18,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                mode.label,
                style: TextStyle(
                  color: selected ? RoomColors.aqua : RoomColors.plum,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: RoomColors.aqua,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class SeatLayoutSheet extends StatelessWidget {
  const SeatLayoutSheet({
    super.key,
    required this.selectedLayout,
    required this.onSelected,
  });

  final String selectedLayout;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final layouts = [
      ...SeatLayoutSpec.withoutHostLayouts,
      ...SeatLayoutSpec.withHostLayouts,
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(width: 42),
          const SizedBox(height: 8),
          const Text(
            'Seat Layout',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: layouts.map((layout) {
              final spec = SeatLayoutSpec.parse(layout);
              final selected = layout == selectedLayout;
              return InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () => onSelected(layout),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? RoomColors.plum : const Color(0xFFFCFAF6),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE8DDCF)),
                  ),
                  child: Text(
                    spec.label,
                    style: TextStyle(
                      color: selected ? Colors.white : RoomColors.plum,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
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
