import 'package:flutter/material.dart';

class LiveRoomGamesModule extends StatelessWidget {
  const LiveRoomGamesModule({
    super.key,
    required this.onOpenGames,
    this.compact = true,
  });

  final VoidCallback onOpenGames;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onOpenGames,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 7 : 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_esports_rounded, color: Colors.white, size: 16),
              if (!compact) ...[
                const SizedBox(width: 8),
                const Text(
                  'Games',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
