import 'package:flutter/material.dart';

import '../controllers/live_room_message_controller.dart';
import '../live_room_models.dart';
import 'room_contribution_rankings_sheet.dart';
import 'room_info_sheet.dart';
import 'room_theme.dart';

class RoomTopBar extends StatelessWidget {
  const RoomTopBar({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.privacyMode,
    required this.onlineCount,
    required this.onBack,
    required this.onJoinTap,
    required this.onShare,
    required this.onAnnouncement,
    required this.onSettings,
    required this.onUsersTap,
    required this.admins,
    required this.availableAdminUsers,
    required this.onAddAdmin,
    required this.onRemoveAdmin,
    this.onRoomRankingsTap,
    this.roomLevel = 12,
    this.language = 'Telugu',
    this.canManageAdmins = true,
  });

  final String roomName;
  final String roomId;
  final RoomPrivacyMode privacyMode;
  final int onlineCount;
  final VoidCallback onBack;
  final VoidCallback onJoinTap;
  final VoidCallback onShare;
  final VoidCallback onAnnouncement;
  final VoidCallback onSettings;
  final VoidCallback onUsersTap;
  final List<SeatUser> admins;
  final List<SeatUser> availableAdminUsers;
  final ValueChanged<SeatUser> onAddAdmin;
  final ValueChanged<SeatUser> onRemoveAdmin;
  final VoidCallback? onRoomRankingsTap;
  final int roomLevel;
  final String language;
  final bool canManageAdmins;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            RoundRoomButton(
              icon: Icons.arrow_back_rounded,
              onTap: onBack,
              size: 31,
              iconSize: 18,
              background: Colors.black.withValues(alpha: 0.26),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _RoomNamePill(
                roomName: roomName,
                privacyMode: privacyMode,
                onTap: () => _openRoomInfo(context),
              ),
            ),
            const SizedBox(width: 7),
            _JoinButton(onTap: onJoinTap),
            const SizedBox(width: 6),
            RoundRoomButton(icon: Icons.reply_rounded, onTap: onShare, size: 30, iconSize: 15, background: Colors.black.withValues(alpha: 0.22)),
            const SizedBox(width: 6),
            RoundRoomButton(icon: Icons.campaign_rounded, onTap: onAnnouncement, size: 30, iconSize: 15, background: Colors.black.withValues(alpha: 0.22)),
            if (canManageAdmins) ...[
              const SizedBox(width: 6),
              RoundRoomButton(
                icon: Icons.delete_sweep_rounded,
                onTap: () => _confirmClearChat(context),
                size: 30,
                iconSize: 15,
                background: RoomColors.coral.withValues(alpha: 0.24),
              ),
            ],
            const SizedBox(width: 6),
            RoundRoomButton(icon: Icons.settings_rounded, onTap: onSettings, size: 30, iconSize: 15, background: Colors.black.withValues(alpha: 0.22)),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const SizedBox(width: 2),
            _TrophyButton(onTap: onRoomRankingsTap ?? () => _openDefaultRoomRankings(context)),
            const SizedBox(width: 7),
            _RoomLevelBadge(level: roomLevel),
            const SizedBox(width: 7),
            _OnlineButton(count: onlineCount, onTap: onUsersTap),
          ],
        ),
      ],
    );
  }

  void _openRoomInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomInfoSheet(
        roomName: roomName,
        roomId: roomId,
        language: language,
        privacyMode: privacyMode,
        canManageAdmins: canManageAdmins,
        admins: admins,
        availableAdminUsers: availableAdminUsers,
        onAddAdmin: onAddAdmin,
        onRemoveAdmin: onRemoveAdmin,
      ),
    );
  }

  void _confirmClearChat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            18,
            12,
            18,
            MediaQuery.paddingOf(sheetContext).bottom + 18,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(width: 42),
              const SizedBox(height: 14),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: RoomColors.coral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.delete_sweep_rounded,
                  color: RoomColors.coral,
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Clear chat for everyone?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RoomColors.plum,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Only room owner/admins can use this. It removes all visible room chat messages for every user in this room.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF7B6A86),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        LiveRoomMessageController.clearActiveRoomChatForEveryone();
                        RoomToast.show(context, 'Chat cleared for everyone');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RoomColors.coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDefaultRoomRankings(BuildContext context) {
    final users = <SeatUser>[];
    final ids = <String>{};
    for (final user in mockRoomUsers) {
      if (ids.add(user.id)) users.add(user);
    }
    for (final user in mockInviteUsers) {
      if (ids.add(user.id)) users.add(user);
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RoomContributionRankingsSheet(roomName: roomName, users: users),
    );
  }
}

class _RoomNamePill extends StatelessWidget {
  const _RoomNamePill({required this.roomName, required this.privacyMode, required this.onTap});

  final String roomName;
  final RoomPrivacyMode privacyMode;
  final VoidCallback onTap;

  String get _cleanRoomName {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return 'Room';
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.black.withValues(alpha: 0.36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 14, offset: const Offset(0, 7))],
          ),
          child: Row(
            children: [
              _PrivacyIcon(mode: privacyMode),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _cleanRoomName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 10.8, fontWeight: FontWeight.w900, letterSpacing: 0.02, height: 1),
                ),
              ),
              const SizedBox(width: 5),
              Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.72), size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyIcon extends StatelessWidget {
  const _PrivacyIcon({required this.mode});

  final RoomPrivacyMode mode;

  @override
  Widget build(BuildContext context) {
    final color = mode == RoomPrivacyMode.open ? RoomColors.aqua : RoomColors.gold;
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.26), width: 0.8)),
      child: Icon(mode.icon, color: color, size: 10),
    );
  }
}

class _RoomLevelBadge extends StatelessWidget {
  const _RoomLevelBadge({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => RoomToast.show(context, 'Room level details will connect here'),
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(colors: [RoomColors.gold.withValues(alpha: 0.30), RoomColors.violet.withValues(alpha: 0.22)]),
            border: Border.all(color: RoomColors.gold.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded, color: RoomColors.gold, size: 13),
              const SizedBox(width: 3),
              Text('Lv.$level', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, height: 1)),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoomColors.aqua.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 31,
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: RoomColors.aqua.withValues(alpha: 0.42)), boxShadow: [BoxShadow(color: RoomColors.aqua.withValues(alpha: 0.14), blurRadius: 14, offset: const Offset(0, 5))]),
          child: const Icon(Icons.add_rounded, color: RoomColors.aqua, size: 21),
        ),
      ),
    );
  }
}

class _TrophyButton extends StatelessWidget {
  const _TrophyButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 31,
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RoomColors.gold.withValues(alpha: 0.96), RoomColors.coral.withValues(alpha: 0.84)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            boxShadow: [BoxShadow(color: RoomColors.gold.withValues(alpha: 0.20), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

class _OnlineButton extends StatelessWidget {
  const _OnlineButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 31,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.32), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.11))),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, color: RoomColors.aqua, size: 13),
              const SizedBox(width: 4),
              Text('$count', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }
}
