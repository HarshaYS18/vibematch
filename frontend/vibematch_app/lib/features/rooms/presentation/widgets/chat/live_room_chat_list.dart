import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';

class LiveRoomChatList extends StatelessWidget {
  const LiveRoomChatList({
    super.key,
    required this.messages,
    required this.onSeatApplicationTap,
  });

  final List<ChatEntry> messages;
  final ValueChanged<ChatEntry> onSeatApplicationTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListView.separated(
        key: const PageStorageKey<String>('live-room-chat-list'),
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        physics: const BouncingScrollPhysics(),
        itemCount: messages.length,
        separatorBuilder: (context, index) => const SizedBox(height: 7),
        itemBuilder: (context, index) {
          final entry = messages[index];
          return _LiveRoomChatEntryBubble(
            key: ValueKey<String>('${entry.senderId ?? entry.senderName}-${entry.message}-$index'),
            entry: entry,
            onSeatApplicationTap: () => onSeatApplicationTap(entry),
          );
        },
      ),
    );
  }
}

class _LiveRoomChatEntryBubble extends StatelessWidget {
  const _LiveRoomChatEntryBubble({
    super.key,
    required this.entry,
    required this.onSeatApplicationTap,
  });

  final ChatEntry entry;
  final VoidCallback onSeatApplicationTap;

  bool get _isSystem => entry.senderId == 'system' || entry.senderName.toLowerCase() == 'system';

  @override
  Widget build(BuildContext context) {
    final isGift = entry.isGift;
    final isApplication = entry.isSeatApplication;

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: isApplication ? onSeatApplicationTap : null,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 315),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: _bubbleColor(isGift: isGift, isApplication: isApplication),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: _bubbleBorder(isGift: isGift, isApplication: isApplication),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isSystem) ...[
                _ChatAvatarLetter(name: entry.senderName),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isSystem)
                      Text(
                        entry.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isGift ? RoomColors.gold : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    Text(
                      entry.message,
                      style: TextStyle(
                        color: _isSystem ? const Color(0xFFE2D9FF) : Colors.white,
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isApplication)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Tap to review request',
                          style: TextStyle(
                            color: RoomColors.aqua,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
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

  Color _bubbleColor({required bool isGift, required bool isApplication}) {
    if (_isSystem) return Colors.white.withValues(alpha: 0.08);
    if (isGift) return RoomColors.gold.withValues(alpha: 0.16);
    if (isApplication) return RoomColors.aqua.withValues(alpha: 0.14);
    return Colors.black.withValues(alpha: 0.28);
  }

  Color _bubbleBorder({required bool isGift, required bool isApplication}) {
    if (isGift) return RoomColors.gold.withValues(alpha: 0.26);
    if (isApplication) return RoomColors.aqua.withValues(alpha: 0.24);
    return Colors.white.withValues(alpha: 0.08);
  }
}

class _ChatAvatarLetter extends StatelessWidget {
  const _ChatAvatarLetter({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [RoomColors.aqua, RoomColors.violet],
        ),
      ),
      child: Text(
        avatarLetter(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
