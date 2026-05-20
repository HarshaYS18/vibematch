import 'package:flutter/material.dart';

import '../../../../shared/gradient_names/gradient_name_style.dart';
import '../../../../shared/gradient_names/gradient_name_text.dart';
import '../../models/inbox_models.dart';
import 'inbox_light_premium_tokens.dart';
import 'inbox_time_formatters.dart';

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
    final hasUnread = conversation.unreadCount > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
          decoration: BoxDecoration(
            gradient: isHub
                ? LinearGradient(
                    colors: [
                      const Color(0xFFFFF5E8),
                      const Color(0xFFFFF7FB),
                      InboxLightPremiumTokens.pink.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFFFFBFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHub
                  ? InboxLightPremiumTokens.warning.withValues(alpha: 0.28)
                  : InboxLightPremiumTokens.border,
            ),
            boxShadow: [
              BoxShadow(
                color: InboxLightPremiumTokens.ink.withValues(
                  alpha: hasUnread ? 0.095 : 0.055,
                ),
                blurRadius: hasUnread ? 22 : 16,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.80),
                blurRadius: 1,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              _PremiumAvatar(conversation: conversation),
              const SizedBox(width: 11),
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
                              color: InboxLightPremiumTokens.ink,
                              fontSize: 14.8,
                              fontWeight: hasUnread
                                  ? FontWeight.w900
                                  : FontWeight.w800,
                              letterSpacing: -0.18,
                            ),
                          ),
                        ),
                        if (conversation.hasChatStreak) ...[
                          const SizedBox(width: 6),
                          _ChatStreakPill(conversation: conversation),
                        ],
                        const SizedBox(width: 7),
                        Text(
                          inboxLocalTimeLabel(conversation.time),
                          style: TextStyle(
                            color: hasUnread
                                ? InboxLightPremiumTokens.violet
                                : InboxLightPremiumTokens.softMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (conversation.isPinned) ...[
                          const Icon(
                            Icons.push_pin_rounded,
                            color: InboxLightPremiumTokens.gold,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isMuted) ...[
                          const Icon(
                            Icons.volume_off_rounded,
                            color: InboxLightPremiumTokens.muted,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isLockedByBackend) ...[
                          const Icon(
                            Icons.lock_rounded,
                            color: InboxLightPremiumTokens.violet,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isStranger &&
                            !conversation.isStrangerHub) ...[
                          const Icon(
                            Icons.shield_rounded,
                            color: Color(0xFFD97706),
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread
                                  ? const Color(0xFF352045)
                                  : InboxLightPremiumTokens.muted,
                              fontSize: 12.25,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              height: 1.14,
                            ),
                          ),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              gradient: InboxLightPremiumTokens.primaryGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: InboxLightPremiumTokens.pink
                                      .withValues(alpha: 0.22),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                conversation.unreadCount > 99
                                    ? '99+'
                                    : '${conversation.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isHub) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: InboxLightPremiumTokens.warning,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${conversation.requestCount} request${conversation.requestCount == 1 ? '' : 's'} protected separately',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF9A5B00),
                                fontSize: 10.8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
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

class _PremiumAvatar extends StatelessWidget {
  const _PremiumAvatar({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final accent = conversation.isStrangerHub
        ? InboxLightPremiumTokens.warning
        : conversation.colors.last;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2.4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [...conversation.colors, conversation.colors.first],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(2.2),
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
                border: Border.all(color: Colors.white, width: 2.2),
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
                gradient: InboxLightPremiumTokens.aquaGradient,
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
  const _AvatarInitials({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: conversation.colors),
      ),
      child: Center(
        child: Text(
          conversation.avatarText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
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
        : InboxLightPremiumTokens.softMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: activeColor.withValues(alpha: 0.16)),
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
