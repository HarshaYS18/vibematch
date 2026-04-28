import 'package:flutter/material.dart';

import 'room_theme.dart';

enum RoomTextBubbleSource { store, eventReward, vipReward }

class RoomTextBubbleStyle {
  const RoomTextBubbleStyle({
    required this.id,
    required this.name,
    required this.source,
    required this.borderColor,
    required this.backgroundColor,
    this.assetPath,
  });

  final String id;
  final String name;
  final RoomTextBubbleSource source;
  final Color borderColor;
  final Color backgroundColor;
  final String? assetPath;
}

const RoomTextBubbleStyle defaultEventTextBubble = RoomTextBubbleStyle(
  id: 'event_gold_glow',
  name: 'Event Gold Glow',
  source: RoomTextBubbleSource.eventReward,
  borderColor: RoomColors.gold,
  backgroundColor: Color(0x331A1029),
);

class RoomTextBubbleHost extends StatelessWidget {
  const RoomTextBubbleHost({
    super.key,
    required this.child,
    this.bubble,
  });

  final Widget child;
  final RoomTextBubbleStyle? bubble;

  @override
  Widget build(BuildContext context) {
    if (bubble == null) return child;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bubble!.backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bubble!.borderColor.withValues(alpha: 0.42)),
      ),
      child: child,
    );
  }
}
