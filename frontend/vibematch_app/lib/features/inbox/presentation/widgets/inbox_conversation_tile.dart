import 'package:flutter/material.dart';

import '../../../../shared/gradient_names/gradient_name_style.dart';
import '../../../../shared/gradient_names/gradient_name_text.dart';
import '../../models/inbox_models.dart';
import 'inbox_motion.dart';

class InboxConversationTile extends StatelessWidget {
  const InboxConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onLongPress,
    required this.onPin,
    required this.onMute,
    this.remoteActivity,
  });

  final InboxConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPin;
  final VoidCallback onMute;
  final String? remoteActivity;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.unreadCount > 0;
    final accent = _accentColor(conversation);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 7),
      child: Dismissible(
        key: ValueKey<String>('inbox-conversation-${conversation.id}'),
        confirmDismiss: (direction) async {
          if (conversation.isStrangerHub) {
            onTap();
            return false;
          }
          if (direction == DismissDirection.startToEnd) {
            onPin();
          } else {
            onMute();
          }
          return false;
        },
        background: _SwipeAction(
          alignment: Alignment.centerLeft,
          color: const Color(0xFFC99A3B),
          icon: conversation.isPinned
              ? Icons.push_pin_outlined
              : Icons.push_pin_rounded,
          label: conversation.isPinned ? 'Unpin' : 'Pin',
        ),
        secondaryBackground: _SwipeAction(
          alignment: Alignment.centerRight,
          color: const Color(0xFF12C7B7),
          icon: conversation.isMuted
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
          label: conversation.isMuted ? 'Unmute' : 'Mute',
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: InboxMotion.standard,
              curve: InboxMotion.curve,
              padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: unread ? 0.98 : 0.90),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: unread
                      ? accent.withValues(alpha: 0.28)
                      : const Color(0xFFEDE7F6),
                  width: unread ? 1.3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: unread ? 0.14 : 0.055),
                    blurRadius: unread ? 22 : 15,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PremiumAvatar(conversation: conversation),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TileBody(
                      conversation: conversation,
                      remoteActivity: remoteActivity,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _TileTrailing(conversation: conversation, accent: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _accentColor(InboxConversation conversation) {
    if (conversation.isStrangerHub || conversation.isStranger) {
      return const Color(0xFFFF6F61);
    }
    if (conversation.isOfficial) return const Color(0xFFC99A3B);
    if (conversation.isCallLog) return const Color(0xFF12C7B7);
    if (conversation.isRoomInvite) return const Color(0xFF7C3AED);
    return const Color(0xFF251538);
  }
}

class _TileBody extends StatelessWidget {
  const _TileBody({required this.conversation, required this.remoteActivity});

  final InboxConversation conversation;
  final String? remoteActivity;

  @override
  Widget build(BuildContext context) {
    final preview = _PreviewData.resolve(conversation, remoteActivity);
    return Column(
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
                  color: const Color(0xFF21142F),
                  fontSize: 15.2,
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w900
                      : FontWeight.w800,
                ),
              ),
            ),
            if (conversation.isOfficial) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF2DD4BF),
                size: 16,
              ),
            ],
            if (conversation.hasChatStreak) ...[
              const SizedBox(width: 5),
              _StreakPill(conversation: conversation),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Icon(preview.icon, color: preview.color, size: 15),
            const SizedBox(width: 5),
            Expanded(
              child: AnimatedSwitcher(
                duration: InboxMotion.quick,
                child: Text(
                  preview.text,
                  key: ValueKey<String>(
                    '${conversation.id}-${preview.text}-${remoteActivity ?? ''}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: preview.color,
                    fontSize: 12.4,
                    height: 1.15,
                    fontWeight: conversation.unreadCount > 0
                        ? FontWeight.w900
                        : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (conversation.isPinned) ...[
              const _MetaIcon(icon: Icons.push_pin_rounded),
              const SizedBox(width: 6),
            ],
            if (conversation.isMuted) ...[
              const _MetaIcon(icon: Icons.volume_off_rounded),
              const SizedBox(width: 6),
            ],
            if (conversation.isLockedByBackend) ...[
              const _MetaIcon(icon: Icons.lock_rounded),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                conversation.safePresenceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF9B8CA5),
                  fontSize: 10.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TileTrailing extends StatelessWidget {
  const _TileTrailing({required this.conversation, required this.accent});

  final InboxConversation conversation;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            conversation.time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: conversation.unreadCount > 0
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFFA497AF),
              fontSize: 10.3,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: InboxMotion.quick,
            child: conversation.unreadCount > 0
                ? _UnreadBadge(
                    key: ValueKey<int>(conversation.unreadCount),
                    count: conversation.unreadCount,
                  )
                : Icon(
                    Icons.chevron_right_rounded,
                    key: const ValueKey<String>('chevron'),
                    color: accent.withValues(alpha: 0.38),
                    size: 23,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PremiumAvatar extends StatelessWidget {
  const _PremiumAvatar({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = conversation.colors.length > 1
        ? conversation.colors
        : const [Color(0xFF12C7B7), Color(0xFF7C3AED)];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(2.4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: colors),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: conversation.hasAvatarUrl
                  ? Image.network(
                      conversation.avatarUrl!,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (context, error, stackTrace) =>
                          _AvatarInitials(
                            conversation: conversation,
                            colors: colors,
                          ),
                    )
                  : _AvatarInitials(conversation: conversation, colors: colors),
            ),
          ),
        ),
        if (conversation.isOnline && !conversation.isStrangerHub)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 15,
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xFF18D17B),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.4),
              ),
            ),
          ),
        if (conversation.isStrangerHub)
          const Positioned(
            right: -1,
            top: -1,
            child: _AvatarIconBadge(icon: Icons.shield_rounded),
          )
        else if (conversation.isOfficial)
          const Positioned(
            right: -1,
            top: -1,
            child: _AvatarIconBadge(icon: Icons.verified_rounded),
          ),
      ],
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.conversation, required this.colors});

  final InboxConversation conversation;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: Center(
        child: Text(
          conversation.avatarText.trim().isEmpty
              ? 'V'
              : conversation.avatarText.trim().characters.first.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _AvatarIconBadge extends StatelessWidget {
  const _AvatarIconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12C7B7), Color(0xFF7C3AED)],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 11),
    );
  }
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 7),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerRight) ...[
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: color, size: 20),
          if (alignment == Alignment.centerLeft) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF4F9A), Color(0xFF7C3AED)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MetaIcon extends StatelessWidget {
  const _MetaIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: const Color(0xFFC99A3B), size: 13);
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final activeColor = conversation.chatStreakActiveToday
        ? const Color(0xFFFF6B00)
        : const Color(0xFF9B8CA5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 11,
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

class _PreviewData {
  const _PreviewData({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  static _PreviewData resolve(
    InboxConversation conversation,
    String? remoteActivity,
  ) {
    final activity = remoteActivity?.trim();
    if (activity != null && activity.isNotEmpty) {
      return _PreviewData(
        text: _activityText(activity),
        icon: Icons.more_horiz_rounded,
        color: const Color(0xFF12AFA2),
      );
    }

    if (conversation.isLockedByBackend) {
      return const _PreviewData(
        text: 'Locked chat - tap to unlock',
        icon: Icons.lock_rounded,
        color: Color(0xFF7B6A86),
      );
    }

    if (conversation.isStrangerHub) {
      return _PreviewData(
        text: conversation.listPreviewText,
        icon: Icons.shield_rounded,
        color: const Color(0xFFFF6F61),
      );
    }

    final last = conversation.messages.isEmpty
        ? null
        : conversation.messages.last;
    if (last != null && last.isInvite) {
      final roomName =
          last.inviteRoomName ??
          conversation.currentRoomName ??
          last.text.trim();
      return _PreviewData(
        text: roomName.isEmpty ? 'Room invite' : 'Room invite: $roomName',
        icon: Icons.meeting_room_rounded,
        color: const Color(0xFF7C3AED),
      );
    }
    if (conversation.isRoomInvite) {
      final roomName = conversation.currentRoomName ?? conversation.subtitle;
      return _PreviewData(
        text: roomName.trim().isEmpty
            ? 'Room invite'
            : 'Room invite: $roomName',
        icon: Icons.meeting_room_rounded,
        color: const Color(0xFF7C3AED),
      );
    }
    if ((last != null && last.type == InboxMessageType.callLog) ||
        conversation.isCallLog) {
      return _PreviewData(
        text: conversation.subtitle.trim().isEmpty
            ? 'Call summary'
            : conversation.subtitle,
        icon: Icons.call_rounded,
        color: const Color(0xFF12AFA2),
      );
    }
    if (last != null && last.type == InboxMessageType.image) {
      return const _PreviewData(
        text: 'Photo',
        icon: Icons.photo_rounded,
        color: Color(0xFF5E4B6F),
      );
    }
    if (last != null && last.type == InboxMessageType.voice) {
      return const _PreviewData(
        text: 'Voice message',
        icon: Icons.mic_rounded,
        color: Color(0xFF5E4B6F),
      );
    }
    if (last != null && last.type == InboxMessageType.system) {
      return _PreviewData(
        text: last.text.trim().isEmpty ? 'System update' : last.text,
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFFC99A3B),
      );
    }
    if (conversation.isOfficial) {
      return _PreviewData(
        text: conversation.listPreviewText,
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFC99A3B),
      );
    }
    return _PreviewData(
      text: conversation.listPreviewText,
      icon: conversation.unreadCount > 0
          ? Icons.chat_bubble_rounded
          : Icons.chat_bubble_outline_rounded,
      color: conversation.unreadCount > 0
          ? const Color(0xFF4A2A63)
          : const Color(0xFF6F607A),
    );
  }

  static String _activityText(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('typing')) return 'typing...';
    if (value.contains('record')) return 'recording voice...';
    return raw;
  }
}
