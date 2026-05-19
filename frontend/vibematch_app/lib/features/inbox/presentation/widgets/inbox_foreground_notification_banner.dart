import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';

class InboxForegroundNotificationBanner extends StatelessWidget {
  const InboxForegroundNotificationBanner({
    super.key,
    required this.conversation,
    required this.message,
    required this.onTap,
    required this.onClose,
  });

  final InboxConversation conversation;
  final InboxMessage message;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = conversation.avatarUrl?.trim();
    final dismissKey = ValueKey<String>(
      'inbox_banner_${conversation.id}_${message.id ?? message.time}_${message.text.hashCode}',
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -220) onClose();
          },
          child: Dismissible(
            key: dismissKey,
            direction: DismissDirection.horizontal,
            resizeDuration: const Duration(milliseconds: 120),
            movementDuration: const Duration(milliseconds: 180),
            onDismissed: (_) => onClose(),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1C0F2D), Color(0xFF4C1D95)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF251538).withValues(alpha: 0.28),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(colors: conversation.colors),
                        ),
                        child: ClipOval(
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? _AvatarText(
                                  text: conversation.avatarText,
                                  colors: conversation.colors,
                                )
                              : Image.network(
                                  avatarUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _AvatarText(
                                    text: conversation.avatarText,
                                    colors: conversation.colors,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.notifications_active_rounded,
                                  color: Color(0xFF2DD4BF),
                                  size: 13,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    conversation.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _previewText(message),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE9D5FF),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.swipe_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _previewText(InboxMessage message) {
    return switch (message.type) {
      InboxMessageType.image => 'Photo',
      InboxMessageType.document =>
        message.text.trim().isEmpty ? 'Document' : message.text,
      InboxMessageType.voice => 'Voice message',
      InboxMessageType.roomInvite =>
        message.inviteRoomName == null
            ? 'Room invite'
            : 'Room invite: ${message.inviteRoomName}',
      InboxMessageType.relationshipRequest => 'Relationship request',
      InboxMessageType.system => message.text,
      _ => message.text,
    };
  }
}

class _AvatarText extends StatelessWidget {
  const _AvatarText({required this.text, required this.colors});

  final String text;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
