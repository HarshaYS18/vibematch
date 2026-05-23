import 'package:flutter/material.dart';

import '../../../../shared/gradient_names/gradient_name_style.dart';
import '../../../../shared/gradient_names/gradient_name_text.dart';
import '../../models/inbox_models.dart';

class InboxConversationCard extends StatelessWidget {
  const InboxConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
  });

  final InboxConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const _ink = Color(0xFF111114);
  static const _muted = Color(0xFF71717A);
  static const _soft = Color(0xFFA1A1AA);
  static const _divider = Color(0xFFEDEDEF);
  static const _surface = Color(0xFFFFFFFF);
  static const _blue = Color(0xFF3797F0);
  static const _green = Color(0xFF22C55E);
  static const _request = Color(0xFFF59E0B);
  static const _teal = Color(0xFF14B8A6);

  @override
  Widget build(BuildContext context) {
    final preview = conversation.listPreviewText;
    final hasUnread = conversation.unreadCount > 0;
    final accent = _accentColor;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            constraints: const BoxConstraints(minHeight: 92),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: hasUnread ? accent.withValues(alpha: 0.24) : _divider,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withValues(alpha: 0.055),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              children: [
                _CleanAvatar(conversation: conversation, accent: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GradientNameText(
                              conversation.title,
                              style: conversation.isOfficial
                                  ? GradientNameStyle.official
                                  : GradientNameStyle.defaultName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textStyle: TextStyle(
                                color: _ink,
                                fontSize: 15.6,
                                fontWeight: hasUnread
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                          if (conversation.hasChatStreak) ...[
                            const SizedBox(width: 6),
                            _ChatStreakPill(conversation: conversation),
                          ],
                          const SizedBox(width: 8),
                          Text(
                            conversation.time,
                            style: TextStyle(
                              color: hasUnread ? accent : _soft,
                              fontSize: 11,
                              fontWeight: hasUnread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread ? _ink : _muted,
                          fontSize: 13.1,
                          fontWeight: hasUnread
                              ? FontWeight.w800
                              : FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          _StatusTag(label: _statusLabel, color: _statusColor),
                          if (conversation.isPinned)
                            const _TinyStateIcon(
                              icon: Icons.push_pin_rounded,
                              color: Color(0xFFC99732),
                            ),
                          if (conversation.isMuted)
                            const _TinyStateIcon(
                              icon: Icons.volume_off_rounded,
                              color: _soft,
                            ),
                          if (conversation.isLockedByBackend)
                            const _TinyStateIcon(
                              icon: Icons.lock_rounded,
                              color: _muted,
                            ),
                          const Spacer(),
                          if (hasUnread)
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 25,
                                minHeight: 23,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [accent, _blue],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Center(
                                child: Text(
                                  conversation.unreadCount > 99
                                      ? '99+'
                                      : '${conversation.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _accentColor {
    if (conversation.isStrangerHub || conversation.isStranger) return _request;
    if (conversation.isOfficial) return _teal;
    if (conversation.isRoomInvite || conversation.isCallLog) return _blue;
    if (conversation.colors.isNotEmpty) return conversation.colors.first;
    return _blue;
  }

  Color get _statusColor {
    if (conversation.isStrangerHub || conversation.isStranger) return _request;
    if (conversation.isOfficial) return _teal;
    if (conversation.isRoomInvite || conversation.isCallLog) return _blue;
    if (conversation.isOnline) return _green;
    return _muted;
  }

  String get _statusLabel {
    if (conversation.isStrangerHub) {
      final count = conversation.requestCount;
      return '$count request${count == 1 ? '' : 's'}';
    }
    if (conversation.isOfficial) return 'Vibe Match Team';
    if (conversation.isRoomInvite) return 'Room invite';
    if (conversation.isCallLog) return 'Call summary';
    if (conversation.isStranger) return 'Stranger Messages';
    if (conversation.isOnline) return 'Online';
    final presence = conversation.safePresenceText.trim();
    return presence.isEmpty ? 'Chat' : presence;
  }
}

class _CleanAvatar extends StatelessWidget {
  const _CleanAvatar({required this.conversation, required this.accent});

  final InboxConversation conversation;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final secondary = conversation.colors.length > 1
        ? conversation.colors.last
        : accent;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(2.4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [accent, secondary]),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: conversation.hasAvatarUrl
                    ? Image.network(
                        conversation.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _AvatarInitials(
                              conversation: conversation,
                              color: accent,
                            ),
                      )
                    : _AvatarInitials(
                        conversation: conversation,
                        color: accent,
                      ),
              ),
            ),
          ),
        ),
        if (conversation.isOnline && !conversation.isStrangerHub)
          Positioned(
            right: 1,
            bottom: 3,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: InboxConversationCard._green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.4),
              ),
            ),
          ),
        if (conversation.isOfficial)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: InboxConversationCard._teal,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: Colors.white,
                size: 10.5,
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.conversation, required this.color});

  final InboxConversation conversation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color),
      child: Center(
        child: Text(
          conversation.avatarText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 10.7,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TinyStateIcon extends StatelessWidget {
  const _TinyStateIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

class _ChatStreakPill extends StatelessWidget {
  const _ChatStreakPill({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final activeColor = conversation.chatStreakActiveToday
        ? const Color(0xFFFF6B00)
        : const Color(0xFFA1A1AA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: activeColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 10.5,
            color: activeColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${conversation.chatStreakCount}',
            style: TextStyle(
              color: activeColor,
              fontSize: 9.4,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
