import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomEmojiSheet extends StatelessWidget {
  const LiveRoomEmojiSheet({
    super.key,
    required this.onEmojiTap,
  });

  final ValueChanged<String> onEmojiTap;

  static const List<String> emojis = [
    '😍',
    '😂',
    '🔥',
    '👏',
    '💖',
    '😎',
    '🎉',
    '💎',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: emojis.map((emoji) {
          return GestureDetector(
            onTap: () => onEmojiTap(emoji),
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RoomColors.pearl,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: RoomColors.softLine),
              ),
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}