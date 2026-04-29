import 'package:flutter/material.dart';

class LiveRoomRankingsModule extends StatelessWidget {
  const LiveRoomRankingsModule({
    super.key,
    required this.sentLabel,
    required this.receivedLabel,
    required this.onSentTap,
    required this.onReceivedTap,
  });

  final String sentLabel;
  final String receivedLabel;
  final VoidCallback onSentTap;
  final VoidCallback onReceivedTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RankingChip(
          label: sentLabel,
          icon: Icons.north_east_rounded,
          onTap: onSentTap,
        ),
        const SizedBox(width: 8),
        _RankingChip(
          label: receivedLabel,
          icon: Icons.south_west_rounded,
          onTap: onReceivedTap,
        ),
      ],
    );
  }
}

class _RankingChip extends StatelessWidget {
  const _RankingChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 13),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
