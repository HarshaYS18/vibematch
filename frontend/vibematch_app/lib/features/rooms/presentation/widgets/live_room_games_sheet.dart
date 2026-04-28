import 'package:flutter/material.dart';

import 'room_theme.dart';

class LiveRoomGamesSheet extends StatelessWidget {
  const LiveRoomGamesSheet({
    super.key,
    required this.onCrystalHuntTap,
    required this.onLudoTap,
    required this.onCarromTap,
    required this.onPkTap,
  });

  final VoidCallback onCrystalHuntTap;
  final VoidCallback onLudoTap;
  final VoidCallback onCarromTap;
  final VoidCallback onPkTap;

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
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniGameChip(
                icon: Icons.casino_rounded,
                label: 'Crystal Hunt',
                onTap: onCrystalHuntTap,
              ),
              _MiniGameChip(
                icon: Icons.sports_esports_rounded,
                label: 'Ludo',
                onTap: onLudoTap,
              ),
              _MiniGameChip(
                icon: Icons.grid_4x4_rounded,
                label: 'Carrom',
                onTap: onCarromTap,
              ),
              _MiniGameChip(
                icon: Icons.emoji_events_rounded,
                label: 'PK',
                onTap: onPkTap,
              ),
            ],
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 138,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFAF6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: RoomColors.softLine),
        ),
        child: Row(
          children: [
            Icon(icon, color: RoomColors.aqua, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: RoomColors.plum,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}