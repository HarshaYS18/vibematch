import 'package:flutter/material.dart';

import 'room_rankings_models.dart';

class RoomRankingsPodiumPreview extends StatelessWidget {
  const RoomRankingsPodiumPreview({
    super.key,
    required this.entries,
    required this.accentColor,
  });

  final List<RoomRankingEntry> entries;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return SizedBox(
      height: 106,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: _PodiumUser(entry: second, height: 72, rank: 2, accentColor: accentColor)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumUser(entry: first, height: 96, rank: 1, accentColor: accentColor)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumUser(entry: third, height: 62, rank: 3, accentColor: accentColor)),
        ],
      ),
    );
  }
}

class _PodiumUser extends StatelessWidget {
  const _PodiumUser({
    required this.entry,
    required this.height,
    required this.rank,
    required this.accentColor,
  });

  final RoomRankingEntry? entry;
  final double height;
  final int rank;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (rank) {
      1 => const Color(0xFFFFD166),
      2 => const Color(0xFFB7C2FF),
      _ => const Color(0xFFFF8FA3),
    };

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            rankColor.withValues(alpha: 0.18),
            accentColor.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: rankColor.withValues(alpha: 0.34)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$rank',
            style: TextStyle(color: rankColor, fontSize: rank == 1 ? 24 : 20, fontWeight: FontWeight.w900, height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            entry?.user.name ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            entry == null ? '' : '${entry!.score}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
