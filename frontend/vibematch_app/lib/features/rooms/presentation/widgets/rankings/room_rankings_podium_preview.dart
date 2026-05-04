import 'package:flutter/material.dart';

import '../../live_room_models.dart';
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
      height: 130,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.06),
                    accentColor.withValues(alpha: 0.20),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _PodiumUser(entry: second, height: 86, rank: 2, accentColor: accentColor)),
              const SizedBox(width: 8),
              Expanded(child: _PodiumUser(entry: first, height: 112, rank: 1, accentColor: accentColor)),
              const SizedBox(width: 8),
              Expanded(child: _PodiumUser(entry: third, height: 80, rank: 3, accentColor: accentColor)),
            ],
          ),
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
            rankColor.withValues(alpha: 0.22),
            accentColor.withValues(alpha: 0.12),
            Colors.black.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: rankColor.withValues(alpha: 0.42)),
        boxShadow: [
          BoxShadow(
            color: rankColor.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _PodiumAvatar(entry: entry, rankColor: rankColor, size: rank == 1 ? 42 : 36),
          const SizedBox(height: 5),
          Text(
            '$rank',
            style: TextStyle(color: rankColor, fontSize: rank == 1 ? 23 : 19, fontWeight: FontWeight.w900, height: 1),
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
            entry == null ? '' : compactNumber(entry!.score),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.58), fontSize: 9, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PodiumAvatar extends StatelessWidget {
  const _PodiumAvatar({required this.entry, required this.rankColor, required this.size});

  final RoomRankingEntry? entry;
  final Color rankColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final user = entry?.user;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: user == null ? null : LinearGradient(colors: user.avatarColors),
        color: user == null ? Colors.white.withValues(alpha: 0.08) : null,
        border: Border.all(color: rankColor.withValues(alpha: 0.70), width: 1.4),
      ),
      child: Text(
        user == null ? '?' : avatarLetter(user.name),
        style: TextStyle(color: Colors.white, fontSize: size * 0.42, fontWeight: FontWeight.w900),
      ),
    );
  }
}
