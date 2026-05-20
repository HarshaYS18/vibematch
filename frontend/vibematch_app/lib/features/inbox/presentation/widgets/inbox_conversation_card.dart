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

  @override
  Widget build(BuildContext context) {
    final preview = conversation.listPreviewText;
    final isHub = conversation.isStrangerHub;
    final hasUnread = conversation.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: isHub ? const Color(0xFFFFFBF2) : _surface,
            border: const Border(bottom: BorderSide(color: _divider, width: 0.7)),
          ),
          child: Row(
            children: [
              _CleanAvatar(conversation: conversation),
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
                            style: conversation.isOfficial ? GradientNameStyle.official : GradientNameStyle.defaultName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textStyle: TextStyle(
                              color: _ink,
                              fontSize: 14.8,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                              letterSpacing: -0.12,
                            ),
                          ),
                        ),
                        if (conversation.hasChatStreak) ...[
                          const SizedBox(width: 5),
                          _ChatStreakPill(conversation: conversation),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          conversation.time,
                          style: TextStyle(
                            color: hasUnread ? _blue : _soft,
                            fontSize: 10.8,
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (conversation.isPinned) ...[
                          const Icon(Icons.push_pin_rounded, color: Color(0xFFC99732), size: 12),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isMuted) ...[
                          const Icon(Icons.volume_off_rounded, color: _soft, size: 12),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isLockedByBackend) ...[
                          const Icon(Icons.lock_rounded, color: _muted, size: 12),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isStranger && !conversation.isStrangerHub) ...[
                          const Icon(Icons.shield_rounded, color: _request, size: 12),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread ? _ink : _muted,
                              fontSize: 12.7,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(color: _blue, shape: BoxShape.circle),
                            child: Center(
                              child: Text(
                                conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 9.4, fontWeight: FontWeight.w800),
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
    );
  }
}

class _CleanAvatar extends StatelessWidget {
  const _CleanAvatar({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final isHub = conversation.isStrangerHub;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHub ? const Color(0xFFFFF3D9) : const Color(0xFFF4F4F5),
          ),
          padding: const EdgeInsets.all(1),
          child: ClipOval(
            child: conversation.hasAvatarUrl
                ? Image.network(
                    conversation.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => _AvatarInitials(conversation: conversation),
                  )
                : _AvatarInitials(conversation: conversation),
          ),
        ),
        if (conversation.isOnline && !conversation.isStrangerHub)
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: InboxConversationCard._green,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        if (conversation.isOfficial)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: InboxConversationCard._blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 9.5),
            ),
          ),
      ],
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final colors = conversation.colors;
    final color = conversation.isStrangerHub ? const Color(0xFFF59E0B) : colors.first;
    return DecoratedBox(
      decoration: BoxDecoration(color: color),
      child: Center(
        child: Text(
          conversation.avatarText,
          style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _ChatStreakPill extends StatelessWidget {
  const _ChatStreakPill({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final activeColor = conversation.chatStreakActiveToday ? const Color(0xFFFF6B00) : const Color(0xFFA1A1AA);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 10, color: activeColor),
          const SizedBox(width: 1),
          Text(
            '${conversation.chatStreakCount}',
            style: TextStyle(color: activeColor, fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
