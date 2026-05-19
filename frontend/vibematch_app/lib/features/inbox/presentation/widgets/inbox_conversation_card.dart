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

  @override
  Widget build(BuildContext context) {
    final preview = conversation.listPreviewText;
    final isHub = conversation.isStrangerHub;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isHub
                  ? const Color(0xFFFFB020).withValues(alpha: 0.30)
                  : const Color(0xFFEDE7F6),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1230).withValues(alpha: 0.045),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _PremiumAvatar(conversation: conversation),
              const SizedBox(width: 10),
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
                              color: const Color(0xFF1D1230),
                              fontSize: 14.4,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w900
                                  : FontWeight.w800,
                              letterSpacing: -0.16,
                            ),
                          ),
                        ),
                        if (conversation.hasChatStreak) ...[
                          const SizedBox(width: 6),
                          _ChatStreakPill(conversation: conversation),
                        ],
                        const SizedBox(width: 7),
                        Text(
                          conversation.time,
                          style: TextStyle(
                            color: conversation.unreadCount > 0
                                ? const Color(0xFF7C3AED)
                                : const Color(0xFF9B8CA5),
                            fontSize: 10.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (conversation.isPinned) ...[
                          const Icon(Icons.push_pin_rounded, color: Color(0xFFC99A3B), size: 13),
                          const SizedBox(width: 3),
                        ],
                        if (conversation.isMuted) ...[
                          const Icon(Icons.volume_off_rounded, color: Color(0xFF9B8CA5), size: 13),
                          const SizedBox(width: 3),
                        ],
                        if (conversation.isLockedByBackend) ...[
                          const Icon(Icons.lock_rounded, color: Color(0xFF7B6A86), size: 13),
                          const SizedBox(width: 3),
                        ],
                        if (conversation.isStranger && !conversation.isStrangerHub) ...[
                          const Icon(Icons.shield_rounded, color: Color(0xFFD97706), size: 13),
                          const SizedBox(width: 3),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: conversation.isLockedByBackend
                                  ? const Color(0xFF7B6A86)
                                  : const Color(0xFF5E4B6F),
                              fontSize: 12.1,
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 7),
                            constraints: const BoxConstraints(minWidth: 19, minHeight: 19),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFFFF4F9A), Color(0xFF7C3AED)],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : '${conversation.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.3,
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
    );
  }
}

class _PremiumAvatar extends StatelessWidget {
  const _PremiumAvatar({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: conversation.colors),
            boxShadow: [
              BoxShadow(
                color: conversation.colors.last.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: conversation.hasAvatarUrl
                  ? Image.network(
                      conversation.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _AvatarInitials(conversation: conversation),
                    )
                  : _AvatarInitials(conversation: conversation),
            ),
          ),
        ),
        if (conversation.isOnline && !conversation.isStrangerHub)
          Positioned(
            right: 1,
            bottom: 2,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF18D17B),
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
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 10),
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
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: conversation.colors)),
      child: Center(
        child: Text(
          conversation.avatarText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
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
    final activeColor = conversation.chatStreakActiveToday
        ? const Color(0xFFFF6B00)
        : const Color(0xFF9B8CA5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: activeColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 11, color: activeColor),
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
