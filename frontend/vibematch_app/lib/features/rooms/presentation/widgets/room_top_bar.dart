import 'package:flutter/material.dart';

import '../live_room_models.dart';
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

  String get _displayName {
    final trimmed = roomName.trim();
    if (trimmed.length <= 25) return trimmed;
    return '${trimmed.substring(0, 25)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            RoundRoomButton(icon: Icons.arrow_back_rounded, onTap: onBack, size: 32, iconSize: 17),
            const SizedBox(width: 8),
            if (privacyMode != RoomPrivacyMode.open) ...[
              _PrivacyDot(mode: privacyMode),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                _displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.2),
              ),
            ),
            const SizedBox(width: 5),
            _JoinButton(onTap: onJoinTap),
            const Spacer(),
            RoundRoomButton(icon: Icons.reply_rounded, onTap: onShare, size: 30, iconSize: 15),
            const SizedBox(width: 4),
            RoundRoomButton(icon: Icons.campaign_rounded, onTap: onAnnouncement, size: 30, iconSize: 15),
            const SizedBox(width: 4),
            RoundRoomButton(icon: Icons.settings_rounded, onTap: onSettings, size: 30, iconSize: 15),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            const _TopChip(icon: Icons.emoji_events_rounded, label: '', compact: true),
            _TopChip(icon: Icons.tag_rounded, label: roomId),
            _TopChip(icon: Icons.groups_rounded, label: '$onlineCount', onTap: onUsersTap),
            if (privacyMode != RoomPrivacyMode.open) _TopChip(icon: privacyMode.icon, label: privacyMode.shortLabel),
          ],
        ),
      ],
    );
  }
}

class _JoinButton extends StatelessWidget {
  const _JoinButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RoomColors.aqua.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: RoomColors.aqua.withValues(alpha: 0.30)),
          ),
          child: const Icon(Icons.add_rounded, color: RoomColors.aqua, size: 17),
        ),
      ),
    );
  }
}

class _PrivacyDot extends StatelessWidget {
  const _PrivacyDot({required this.mode});

  final RoomPrivacyMode mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: RoomColors.gold.withValues(alpha: 0.16), shape: BoxShape.circle, border: Border.all(color: RoomColors.gold.withValues(alpha: 0.28))),
      child: Icon(mode.icon, color: RoomColors.gold, size: 11),
    );
  }
}

class _TopChip extends StatelessWidget {
  const _TopChip({required this.icon, required this.label, this.onTap, this.compact = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 22,
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 7),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: RoomColors.gold, size: 11),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 9.2, fontWeight: FontWeight.w900)),
          ],
        ],
      ),
    );
    if (onTap == null) return child;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(999), onTap: onTap, child: child));
  }
}
