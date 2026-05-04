import 'package:flutter/material.dart';

import '../../models/inbox_models.dart';

class InboxChatPage extends StatelessWidget {
  const InboxChatPage({
    super.key,
    required this.conversation,
    required this.onMoreTap,
    this.onBackTap,
  });

  final InboxConversation conversation;
  final VoidCallback onMoreTap;
  final VoidCallback? onBackTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              conversation: conversation,
              onBackTap: onBackTap ?? () => Navigator.pop(context),
              onMoreTap: onMoreTap,
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                itemCount: conversation.messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _MessageBubble(
                    message: conversation.messages[index],
                    conversation: conversation,
                  );
                },
              ),
            ),
            _ChatInputBar(readOnly: conversation.isOfficial || conversation.isStranger || conversation.isBlocked),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.conversation,
    required this.onBackTap,
    required this.onMoreTap,
  });

  final InboxConversation conversation;
  final VoidCallback onBackTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFECE2D8))),
      ),
      child: Row(
        children: [
          IconButton(onPressed: onBackTap, icon: const Icon(Icons.arrow_back_rounded)),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: conversation.colors),
            ),
            child: Center(
              child: Text(
                conversation.avatarText,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF251538),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  conversation.currentRoomName == null
                      ? conversation.lastSeenText
                      : 'In ${conversation.currentRoomName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7B6A86),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onMoreTap, icon: const Icon(Icons.more_horiz_rounded)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.conversation});

  final InboxMessage message;
  final InboxConversation conversation;

  @override
  Widget build(BuildContext context) {
    final mine = message.isMine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 285),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF251538) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: mine ? null : Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: mine ? Colors.white : const Color(0xFF251538),
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message.time,
              style: TextStyle(
                color: mine ? Colors.white70 : const Color(0xFF9B8CA5),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({required this.readOnly});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + MediaQuery.paddingOf(context).bottom),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECE2D8)),
              ),
              alignment: Alignment.centerLeft,
              child: Text(
                readOnly ? 'Replies disabled for this chat' : 'Message...',
                style: const TextStyle(color: Color(0xFF8C8198), fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF12C7B7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}
