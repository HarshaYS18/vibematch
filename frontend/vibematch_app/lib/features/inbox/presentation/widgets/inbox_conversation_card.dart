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
    final preview = _previewText(conversation);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        splashColor: const Color(0xFF251538).withValues(alpha: 0.04),
        highlightColor: const Color(0xFF251538).withValues(alpha: 0.035),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
          child: Row(
            children: [
              _InboxAvatar(conversation: conversation),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: const Color(0xFF251538).withValues(alpha: 0.055),
                        width: 0.7,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
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
                                      color: const Color(0xFF17111F),
                                      fontSize: 15.4,
                                      fontWeight: conversation.unreadCount > 0
                                          ? FontWeight.w900
                                          : FontWeight.w800,
                                      letterSpacing: -0.15,
                                    ),
                                  ),
                                ),
                                if (conversation.isOfficial) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFFC99A3B),
                                    size: 15,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (conversation.isPinned) ...[
                                  const Icon(
                                    Icons.push_pin_rounded,
                                    color: Color(0xFFC99A3B),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                if (conversation.isMuted) ...[
                                  const Icon(
                                    Icons.volume_off_rounded,
                                    color: Color(0xFF8E8198),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                if (conversation.isLockedByBackend) ...[
                                  const Icon(
                                    Icons.lock_rounded,
                                    color: Color(0xFF8E8198),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Expanded(
                                  child: Text(
                                    preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: conversation.unreadCount > 0
                                          ? const Color(0xFF251538)
                                          : const Color(0xFF756A7D),
                                      fontSize: 12.8,
                                      height: 1.1,
                                      fontWeight: conversation.unreadCount > 0
                                          ? FontWeight.w800
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            conversation.time,
                            style: TextStyle(
                              color: conversation.unreadCount > 0
                                  ? const Color(0xFF12C7B7)
                                  : const Color(0xFF9B91A3),
                              fontSize: 10.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          if (conversation.unreadCount > 0)
                            _UnreadDot(count: conversation.unreadCount)
                          else if (conversation.hasChatStreak)
                            _StreakInline(conversation: conversation),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewText(InboxConversation conversation) {
    if (conversation.isStrangerHub) return conversation.listPreviewText;
    final last = conversation.messages.isEmpty ? null : conversation.messages.last;
    if (last?.isInvite == true) {
      return 'Room invite • ${last!.inviteRoomName ?? conversation.currentRoomName ?? 'Tap to join'}';
    }
    if (last?.type == InboxMessageType.callLog) return 'Call • ${last!.text}';
    if (last?.type == InboxMessageType.image) return 'Photo • ${last!.text}';
    if (last?.type == InboxMessageType.voice) return 'Voice message';
    if (last?.type == InboxMessageType.document) return 'Document • ${last!.text}';
    return conversation.listPreviewText;
  }
}

class _InboxAvatar extends StatelessWidget {
  const _InboxAvatar({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 54,
          height: 54,
          padding: const EdgeInsets.all(2.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: conversation.isStrangerHub
                ? const LinearGradient(colors: [Color(0xFFFFB020), Color(0xFFE84C72)])
                : LinearGradient(colors: conversation.colors),
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFAF7F1),
            ),
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
            right: 2,
            bottom: 3,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF18D17B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFAF7F1), width: 2),
              ),
            ),
          ),
        if (conversation.isOfficial)
          Positioned(
            right: -1,
            top: -2,
            child: Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                color: const Color(0xFFC99A3B),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFAF7F1), width: 2),
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 10),
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

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 21, minHeight: 21),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: const BoxDecoration(
        color: Color(0xFF12C7B7),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.2,
          height: 1,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StreakInline extends StatelessWidget {
  const _StreakInline({required this.conversation});

  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final color = conversation.chatStreakActiveToday
        ? const Color(0xFFFF6B00)
        : const Color(0xFF9B8CA5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department_rounded, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          '${conversation.chatStreakCount}',
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
