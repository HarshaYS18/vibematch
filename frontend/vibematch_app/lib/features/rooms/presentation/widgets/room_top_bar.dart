import 'package:flutter/material.dart';

import '../../data/room_level_service.dart';
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
    this.onRoomLevelTap,
    this.roomLevel = 1,
    this.language = 'Telugu',
    this.canManageAdmins = true,
    this.currentUserIsMember = false,
    this.joinRequestPending = false,
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
  final VoidCallback? onRoomLevelTap;
  final int roomLevel;
  final String language;
  final bool canManageAdmins;
  final bool currentUserIsMember;
  final bool joinRequestPending;

  @override
  Widget build(BuildContext context) {
    final openRankings = onRoomRankingsTap ?? () => _openDefaultRoomRankings(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            RoundRoomButton(icon: Icons.arrow_back_rounded, onTap: onBack, size: 28, iconSize: 16, background: Colors.black.withValues(alpha: 0.24)),
            const SizedBox(width: 5),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 112, maxWidth: 198),
                  child: _RoomNamePill(
                    roomName: roomName,
                    privacyMode: privacyMode,
                    onInfoTap: () => _openRoomInfo(context),
                    onJoinTap: onJoinTap,
                    showJoinButton: !canManageAdmins,
                    currentUserIsMember: currentUserIsMember,
                    joinRequestPending: joinRequestPending,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            RoundRoomButton(icon: Icons.send_rounded, onTap: onShare, size: 27, iconSize: 14, background: Colors.black.withValues(alpha: 0.20)),
            const SizedBox(width: 5),
            RoundRoomButton(icon: Icons.campaign_rounded, onTap: onAnnouncement, size: 27, iconSize: 14, background: Colors.black.withValues(alpha: 0.20)),
            if (canManageAdmins) ...[
              const SizedBox(width: 5),
              RoundRoomButton(icon: Icons.settings_rounded, onTap: onSettings, size: 27, iconSize: 14, background: Colors.black.withValues(alpha: 0.20)),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const SizedBox(width: 2),
            _TrophyButton(onTap: openRankings),
            const SizedBox(width: 5),
            _DynamicRoomLevelBadge(roomPublicId: roomId, fallbackLevel: roomLevel, onTap: onRoomLevelTap),
            const SizedBox(width: 5),
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
      builder: (_) => RoomInfoSheet(roomName: roomName, roomId: roomId, language: language, privacyMode: privacyMode, canManageAdmins: canManageAdmins, admins: admins, availableAdminUsers: availableAdminUsers, onAddAdmin: onAddAdmin, onRemoveAdmin: onRemoveAdmin),
    );
  }

  void _openDefaultRoomRankings(BuildContext context) {
    showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => RoomContributionRankingsSheet(roomName: roomName, roomPublicId: roomId, users: const <SeatUser>[]));
  }
}

class _RoomNamePill extends StatelessWidget {
  const _RoomNamePill({
    required this.roomName,
    required this.privacyMode,
    required this.onInfoTap,
    required this.onJoinTap,
    required this.showJoinButton,
    required this.currentUserIsMember,
    required this.joinRequestPending,
  });

  final String roomName;
  final RoomPrivacyMode privacyMode;
  final VoidCallback onInfoTap;
  final VoidCallback onJoinTap;
  final bool showJoinButton;
  final bool currentUserIsMember;
  final bool joinRequestPending;

  String get _cleanRoomName => roomName.trim().isEmpty ? 'Room' : roomName.trim();

  bool get _showMemberIcon => showJoinButton && currentUserIsMember;
  bool get _showPlusButton => showJoinButton && !currentUserIsMember && !joinRequestPending;
  bool get _showTrailingSlot => _showMemberIcon || _showPlusButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: Colors.black.withValues(alpha: 0.34), border: Border.all(color: Colors.white.withValues(alpha: 0.11)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 11, offset: const Offset(0, 5))]),
      child: Row(children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(999)),
            child: InkWell(
              borderRadius: BorderRadius.horizontal(left: const Radius.circular(999), right: Radius.circular(_showTrailingSlot ? 0 : 999)),
              onTap: onInfoTap,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, right: 3),
                child: Row(children: [_PrivacyIcon(mode: privacyMode), const SizedBox(width: 5), Flexible(child: Text(_cleanRoomName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.01, height: 1))), const SizedBox(width: 3), Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white.withValues(alpha: 0.72), size: 13)]),
              ),
            ),
          ),
        ),
        if (_showTrailingSlot) ...[
          Container(width: 1, height: 16, color: Colors.white.withValues(alpha: 0.12)),
          if (_showMemberIcon)
            const SizedBox(width: 28, height: 28, child: Center(child: Icon(Icons.verified_user_rounded, color: RoomColors.aqua, size: 15)))
          else
            Material(color: Colors.transparent, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: onJoinTap, child: const SizedBox(width: 28, height: 28, child: Center(child: Icon(Icons.add_rounded, color: RoomColors.aqua, size: 17))))),
        ],
      ]),
    );
  }
}

class _PrivacyIcon extends StatelessWidget {
  const _PrivacyIcon({required this.mode});
  final RoomPrivacyMode mode;
  @override
  Widget build(BuildContext context) {
    final color = mode == RoomPrivacyMode.open ? RoomColors.aqua : RoomColors.gold;
    return Container(width: 16, height: 16, decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.24), width: 0.7)), child: Icon(mode.icon, color: color, size: 9));
  }
}

class _DynamicRoomLevelBadge extends StatelessWidget {
  const _DynamicRoomLevelBadge({required this.roomPublicId, required this.fallbackLevel, this.onTap});

  final String roomPublicId;
  final int fallbackLevel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RoomLevelSummary>(
      future: RoomLevelService.instance.fetchRoomLevel(roomPublicId: roomPublicId, fallbackLevel: fallbackLevel),
      builder: (context, snapshot) {
        final level = snapshot.data?.level ?? fallbackLevel;
        return _RoomLevelBadge(level: level <= 0 ? 1 : level, onTap: onTap);
      },
    );
  }
}

class _RoomLevelBadge extends StatelessWidget {
  const _RoomLevelBadge({required this.level, this.onTap});
  final int level;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, borderRadius: BorderRadius.circular(999), child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: Container(height: 28, padding: const EdgeInsets.symmetric(horizontal: 7), decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), gradient: LinearGradient(colors: [RoomColors.gold.withValues(alpha: 0.28), RoomColors.violet.withValues(alpha: 0.20)]), border: Border.all(color: RoomColors.gold.withValues(alpha: 0.26))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.local_fire_department_rounded, color: RoomColors.gold, size: 12), const SizedBox(width: 3), Text('Lv.$level', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, height: 1))]))));
}

class _TrophyButton extends StatelessWidget {
  const _TrophyButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RoomColors.gold.withValues(alpha: 0.94), RoomColors.coral.withValues(alpha: 0.82)]), border: Border.all(color: Colors.white.withValues(alpha: 0.22)), boxShadow: [BoxShadow(color: RoomColors.gold.withValues(alpha: 0.16), blurRadius: 11, offset: const Offset(0, 4))]), child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 14))));
}

class _OnlineButton extends StatelessWidget {
  const _OnlineButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, borderRadius: BorderRadius.circular(999), child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: Container(height: 28, padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.30), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: 0.10))), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.groups_rounded, color: RoomColors.aqua, size: 12), const SizedBox(width: 3), Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900))]))));
}
