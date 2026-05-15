import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomGamesSheet extends StatelessWidget {
  const LiveRoomGamesSheet({
    super.key,
    required this.onJungleHuntTap,
    required this.onCoinGameRankingsTap,
  });

  final VoidCallback onJungleHuntTap;
  final VoidCallback onCoinGameRankingsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 12),
          const Text(
            'Games',
            style: TextStyle(
              color: RoomColors.plum,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Available room games',
            style: TextStyle(
              color: RoomColors.plum.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _MiniGameChip(
            icon: Icons.pets_rounded,
            label: 'Jungle Hunt',
            subtitle: 'Coin game • backend result',
            onTap: onJungleHuntTap,
          ),
          const SizedBox(height: 9),
          _MiniGameChip(
            icon: Icons.emoji_events_rounded,
            label: 'Coin Game Rankings',
            subtitle: 'Winnings • bidding • losses',
            onTap: onCoinGameRankingsTap,
          ),
        ],
      ),
    );
  }
}

class _MiniGameChip extends StatelessWidget {
  const _MiniGameChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: RoomColors.softLine),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: RoomColors.aqua.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: RoomColors.aqua, size: 23),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RoomColors.plum,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: RoomColors.plum.withValues(alpha: 0.56),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: RoomColors.plum),
          ],
        ),
      ),
    );
  }
}
