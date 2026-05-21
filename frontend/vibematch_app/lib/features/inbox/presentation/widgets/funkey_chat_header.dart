import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';

class FunKeyChatHeader extends StatelessWidget {
  const FunKeyChatHeader({
    super.key,
    required this.conversation,
    required this.statusText,
    required this.onBackTap,
    required this.onMoreTap,
    required this.onVoiceCallTap,
    required this.onVideoCallTap,
  });

  final InboxConversation conversation;
  final String statusText;
  final VoidCallback onBackTap;
  final VoidCallback onMoreTap;
  final VoidCallback onVoiceCallTap;
  final VoidCallback onVideoCallTap;

  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _line = Color(0xFFEDEDEF);
  static const _blue = Color(0xFF3797F0);

  @override
  Widget build(BuildContext context) {
    final avatarUrl = conversation.avatarUrl?.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: _line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onBackTap,
            icon: const Icon(Icons.arrow_back_rounded, color: _ink, size: 22),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF1F1F3),
                backgroundImage: avatarUrl == null || avatarUrl.isEmpty ? null : NetworkImage(avatarUrl),
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        conversation.avatarText,
                        style: const TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.w800),
                      )
                    : null,
              ),
              if (conversation.isOnline)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontSize: 14.6, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (conversation.isOfficial) const Icon(Icons.verified_rounded, color: _blue, size: 14),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11.2, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (conversation.hasChatStreak) ...[
            _HeaderChatStreakPill(conversation: conversation),
            const SizedBox(width: 2),
          ],
          _HeaderIcon(icon: Icons.call_rounded, onTap: onVoiceCallTap),
          _HeaderIcon(icon: Icons.videocam_rounded, onTap: onVideoCallTap),
          _HeaderIcon(icon: Icons.more_vert_rounded, onTap: onMoreTap),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      onPressed: onTap,
      icon: Icon(icon, color: FunKeyChatHeader._ink, size: 20),
    );
  }
}

class _HeaderChatStreakPill extends StatelessWidget {
  const _HeaderChatStreakPill({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final color = conversation.chatStreakActiveToday ? const Color(0xFFFF6B00) : FunKeyChatHeader._muted;
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, color: color, size: 11),
          Text(
            '${conversation.chatStreakCount}',
            style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
