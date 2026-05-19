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
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isHub ? const Color(0xFFFFB020).withValues(alpha: 0.34) : const Color(0xFFEDE7F6),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E1230).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              _PremiumAvatar(conversation: conversation),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
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
                              color: const Color(0xFF1D1230),
                              fontSize: 15.5,
                              fontWeight: conversation.unreadCount > 0 ? FontWeight.w900 : FontWeight.w800,
                              letterSpacing: -0.18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          conversation.time,
                          style: TextStyle(
                            color: conversation.unreadCount > 0 ? const Color(0xFF7C3AED) : const Color(0xFF9B8CA5),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (conversation.isPinned) ...[
                          const Icon(Icons.push_pin_rounded, color: Color(0xFFC99A3B), size: 14),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isMuted) ...[
                          const Icon(Icons.volume_off_rounded, color: Color(0xFF9B8CA5), size: 14),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isLockedByBackend) ...[
                          const Icon(Icons.lock_rounded, color: Color(0xFF7B6A86), size: 14),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: conversation.isLockedByBackend ? const Color(0xFF7B6A86) : const Color(0xFF5E4B6F),
                              fontSize: 12.6,
                              fontWeight: conversation.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (conversation.unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFFFF4F9A), Color(0xFF7C3AED)]),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _TypePill(conversation: conversation),
                        const SizedBox(width: 7),
                        if (conversation.hasChatStreak) ...[
                          _ChatStreakPill(conversation: conversation),
                          const SizedBox(width: 7),
                        ],
                        Expanded(
                          child: Text(
                            conversation.safePresenceText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF8B7A99), fontSize: 11.2, fontWeight: FontWeight.w700),
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
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: conversation.colors),
            boxShadow: [
              BoxShadow(
                color: conversation.colors.last.withValues(alpha: 0.22),
                blurRadius: 14,
                offset: const Offset(0, 6),
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
                      errorBuilder: (context, error, stackTrace) => _AvatarInitials(conversation: conversation),
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
              width: 14,
              height: 14,
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
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                color: const Color(0xFF2DD4BF),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 11),
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
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = conversation.isOfficial
        ? ('Team', const Color(0xFF0F766E), Icons.verified_rounded)
        : conversation.isStranger
            ? ('Request', const Color(0xFFD97706), Icons.shield_rounded)
            : conversation.isRoomInvite
                ? ('Invite', const Color(0xFF2563EB), Icons.meeting_room_rounded)
                : conversation.isGroup
                    ? ('Group', const Color(0xFF7C3AED), Icons.groups_rounded)
                    : ('Friend', const Color(0xFF059669), Icons.favorite_rounded);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w900)),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: activeColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 11, color: activeColor),
          const SizedBox(width: 3),
          Text(
            '${conversation.chatStreakCount}',
            style: TextStyle(
              color: activeColor,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
