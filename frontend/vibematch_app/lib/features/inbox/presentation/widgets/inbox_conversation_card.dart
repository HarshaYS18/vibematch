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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      gradient: LinearGradient(colors: conversation.colors),
                    ),
                    child: Center(
                      child: Text(
                        conversation.avatarText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  if (conversation.isOnline)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF12C7B7),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFAF7F1), width: 2),
                        ),
                      ),
                    ),
                  if (conversation.isPinned)
                    Positioned(
                      left: -4,
                      top: -5,
                      child: _StateBadge(
                        icon: Icons.push_pin_rounded,
                        background: const Color(0xFFFFF4D7),
                        color: const Color(0xFFC99A3B),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
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
                            style: const TextStyle(
                              color: Color(0xFF251538),
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (conversation.isMuted) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.volume_off_rounded, color: Color(0xFF8C8198), size: 14),
                        ],
                        if (conversation.isPinned) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.push_pin_rounded, color: Color(0xFFC99A3B), size: 14),
                        ],
                        if (conversation.isBlocked) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.block_rounded, color: Color(0xFFE84C72), size: 14),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      conversation.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7A6B86),
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _MiniPill(text: conversation.type.label),
                        if (conversation.isPinned) ...[
                          const SizedBox(width: 5),
                          const _StatusPill(
                            text: 'Pinned',
                            icon: Icons.push_pin_rounded,
                            color: Color(0xFFC99A3B),
                          ),
                        ],
                        if (conversation.isMuted) ...[
                          const SizedBox(width: 5),
                          const _StatusPill(
                            text: 'Muted',
                            icon: Icons.volume_off_rounded,
                            color: Color(0xFF8C8198),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            conversation.currentRoomName == null
                                ? conversation.lastSeenText
                                : 'In ${conversation.currentRoomName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8C8198),
                              fontSize: 10.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    conversation.time,
                    style: const TextStyle(
                      color: Color(0xFF9B8CA5),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (conversation.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE84C72),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${conversation.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else if (conversation.isMuted)
                    const Icon(Icons.notifications_off_rounded, color: Color(0xFF8C8198), size: 17)
                  else
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF9B8CA5)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({
    required this.icon,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFFAF7F1), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 10),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 9),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 8.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  const _MiniPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF4A2A63),
        fontSize: 9.8,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}
