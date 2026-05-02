import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';
import 'live_room_chat_list.dart';

class LiveRoomChatSurface extends StatelessWidget {
  const LiveRoomChatSurface({
    super.key,
    required this.messages,
    required this.onSeatApplicationTap,
    required this.onOpenMessages,
  });

  final List<ChatEntry> messages;
  final ValueChanged<ChatEntry> onSeatApplicationTap;
  final VoidCallback onOpenMessages;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _ChatSurfaceHeader(
              messageCount: messages.length,
              onOpenMessages: onOpenMessages,
            ),
            Expanded(
              child: messages.isEmpty
                  ? const _EmptyChatState()
                  : LiveRoomChatList(
                      messages: messages,
                      onSeatApplicationTap: onSeatApplicationTap,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSurfaceHeader extends StatelessWidget {
  const _ChatSurfaceHeader({
    required this.messageCount,
    required this.onOpenMessages,
  });

  final int messageCount;
  final VoidCallback onOpenMessages;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_rounded, color: RoomColors.aqua, size: 15),
          const SizedBox(width: 7),
          const Text(
            'Room Chat',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: RoomColors.aqua.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$messageCount',
              style: const TextStyle(
                color: RoomColors.aqua,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: onOpenMessages,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.open_in_full_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text(
                    'Open',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'No room messages yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFCFC7DD),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
