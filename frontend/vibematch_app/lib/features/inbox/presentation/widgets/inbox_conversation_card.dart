import 'package:flutter/material.dart';

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
    final activityText = conversation.currentRoomName == null
        ? conversation.lastSeenText
        : 'In chatroom: ${conversation.currentRoomName}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 12, 9),
          child: Row(
            children: [
              _WhatsAppAvatar(conversation: conversation),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF111B21),
                              fontSize: 16,
                              fontWeight: conversation.unreadCount > 0 ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                        Text(
                          conversation.time,
                          style: TextStyle(
                            color: conversation.unreadCount > 0 ? const Color(0xFF25D366) : const Color(0xFF667781),
                            fontSize: 11.5,
                            fontWeight: conversation.unreadCount > 0 ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (conversation.isPinned) ...[
                          const Icon(Icons.push_pin_rounded, color: Color(0xFF667781), size: 14),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isMuted) ...[
                          const Icon(Icons.volume_off_rounded, color: Color(0xFF667781), size: 14),
                          const SizedBox(width: 4),
                        ],
                        if (conversation.isLockedByBackend) ...[
                          const Icon(Icons.lock_rounded, color: Color(0xFF667781), size: 13),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conversation.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: conversation.unreadCount > 0 ? const Color(0xFF111B21) : const Color(0xFF667781),
                              fontSize: 13.2,
                              fontWeight: conversation.unreadCount > 0 ? FontWeight.w700 : FontWeight.w500,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        if (conversation.unreadCount > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TypeDot(conversation: conversation),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            activityText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF8696A0), fontSize: 11.2, fontWeight: FontWeight.w500),
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

class _WhatsAppAvatar extends StatelessWidget {
  const _WhatsAppAvatar({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: conversation.colors),
          ),
          clipBehavior: Clip.antiAlias,
          child: conversation.hasAvatarUrl
              ? Image.network(
                  conversation.avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _AvatarInitials(conversation: conversation),
                )
              : _AvatarInitials(conversation: conversation),
        ),
        if (conversation.isOnline)
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
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
                color: const Color(0xFF00A884),
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
    return Center(
      child: Text(
        conversation.avatarText,
        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TypeDot extends StatelessWidget {
  const _TypeDot({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final color = conversation.isOfficial
        ? const Color(0xFF00A884)
        : conversation.isStranger
            ? const Color(0xFFFFB020)
            : conversation.isRoomInvite
                ? const Color(0xFF53BDEB)
                : const Color(0xFF25D366);
    return Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}
