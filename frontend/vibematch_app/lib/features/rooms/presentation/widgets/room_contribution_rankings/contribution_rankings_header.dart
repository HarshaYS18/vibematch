import 'package:flutter/material.dart';

import '../room_theme.dart';

class RoomContributionRankingsHeader extends StatelessWidget {
  const RoomContributionRankingsHeader({
    super.key,
    required this.roomName,
    required this.onClose,
  });

  final String roomName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [RoomColors.gold, RoomColors.coral]),
            boxShadow: [
              BoxShadow(
                color: RoomColors.gold.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Room Contributions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: RoomColors.plum, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
              ),
              const SizedBox(height: 2),
              Text(
                roomName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF82758E), fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        RoundRoomButton(
          icon: Icons.close_rounded,
          onTap: onClose,
          color: RoomColors.plum,
          background: RoomColors.pearl,
          size: 34,
          iconSize: 18,
        ),
      ],
    );
  }
}
