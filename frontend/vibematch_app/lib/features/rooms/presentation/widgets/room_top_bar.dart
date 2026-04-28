import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_contribution_rankings_sheet.dart';
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
    this.onRoomRankingsTap,
    this.roomLevel = 12,
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
  final VoidCallback? onRoomRankingsTap;
  final int roomLevel;

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
              size: 32,
              iconSize: 18,
              background: Colors.black.withValues(alpha: 0.22),
            ),
            const SizedBox(width: 7),
            Flexible(
              fit: FlexFit.loose,
              child: _RoomIdentityPill(
                roomName: roomName,
                roomId: roomId,
                privacyMode: privacyMode,
              ),
            ),
            const SizedBox(width: 5),
            _RoomLevelBadge(level: roomLevel),
            const SizedBox(width: 5),
            _JoinButton(onTap: onJoinTap),
            const Spacer(),
            _TrophyButton(
              onTap: onRoomRankingsTap ?? () => _openDefaultRoomRankings(context),
            ),
            const SizedBox(width: 5),
            _OnlineButton(count: onlineCount, onTap: onUsersTap),
            const SizedBox(width: 5),
            RoundRoomButton(
              icon: Icons.reply_rounded,
              onTap: onShare,
              size: 31,
              iconSize: 15,
              background: Colors.black.withValues(alpha: 0.20),
            ),
            const SizedBox(width: 5),
            RoundRoomButton(
              icon: Icons.campaign_rounded,
              onTap: onAnnouncement,
              size: 31,
              iconSize: 15,
              background: Colors.black.withValues(alpha: 0.20),
            ),
            const SizedBox(width: 5),
            RoundRoomButton(
              icon: Icons.settings_rounded,
              onTap: onSettings,
              size: 31,
              iconSize: 15,
              background: Colors.black.withValues(alpha: 0.20),
            ),
          ],
        ),
        if (privacyMode != RoomPrivacyMode.open) ...[
          const SizedBox(height: 6),
          _PrivacyStatusChip(mode: privacyMode),
        ],
      ],
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
      builder: (_) => RoomContributionRankingsSheet(
        roomName: roomName,
        users: users,
      ),
    );
  }
}

class _RoomIdentityPill extends StatelessWidget {
  const _RoomIdentityPill({
    required this.roomName,
    required this.roomId,
    required this.privacyMode,
  });

  final String roomName;
  final String roomId;
  final RoomPrivacyMode privacyMode;

  String get _cleanRoomName {
    final trimmed = roomName.trim();
    if (trimmed.isEmpty) return 'Room';
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28, maxWidth: 178),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.black.withValues(alpha: 0.24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (privacyMode != RoomPrivacyMode.open) ...[
              Icon(privacyMode.icon, color: RoomColors.gold, size: 11),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: _cleanRoomName),
                    const TextSpan(
                      text: '  ·  ',
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w900),
                    ),
                    TextSpan(
                      text: roomId,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.6,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.05,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
      ),
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
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [
                RoomColors.gold.withValues(alpha: 0.28),
                RoomColors.violet.withValues(alpha: 0.20),
              ],
            ),
            border: Border.all(color: RoomColors.gold.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded, color: RoomColors.gold, size: 13),
              const SizedBox(width: 3),
              Text(
                'Lv.$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
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
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: RoomColors.aqua.withValues(alpha: 0.40)),
            boxShadow: [
              BoxShadow(
                color: RoomColors.aqua.withValues(alpha: 0.14),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded, color: RoomColors.aqua, size: 20),
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
          width: 29,
          height: 29,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                RoomColors.gold.withValues(alpha: 0.95),
                RoomColors.coral.withValues(alpha: 0.82),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
            boxShadow: [
              BoxShadow(
                color: RoomColors.gold.withValues(alpha: 0.20),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
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
          height: 29,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.groups_rounded, color: RoomColors.aqua, size: 13),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrivacyStatusChip extends StatelessWidget {
  const _PrivacyStatusChip({required this.mode});

  final RoomPrivacyMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: RoomColors.gold.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: RoomColors.gold.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mode.icon, color: RoomColors.gold, size: 11),
          const SizedBox(width: 4),
          Text(
            mode.shortLabel,
            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
