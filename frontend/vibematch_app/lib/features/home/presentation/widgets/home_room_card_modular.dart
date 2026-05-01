import 'package:flutter/material.dart';

import '../../models/home_room_model.dart';

class HomeRoomCardModular extends StatelessWidget {
  const HomeRoomCardModular({
    super.key,
    required this.room,
    required this.rank,
    required this.onTap,
  });

  final HomeRoomModel room;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = _accentForRank(rank);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEDE3D7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.055),
              blurRadius: 18,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.62)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF251538),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ModePill(mode: room.mode),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    room.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 12.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: [
                      _MiniInfo(icon: Icons.language_rounded, text: room.language),
                      _MiniInfo(icon: Icons.people_alt_rounded, text: '${room.onlineCount}'),
                      _MiniInfo(icon: Icons.local_fire_department_rounded, text: '${room.trendingScore}'),
                      if (room.followedFriendsInside.isNotEmpty)
                        _MiniInfo(
                          icon: Icons.favorite_rounded,
                          text: '${room.followedFriendsInside.length} friends',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF8C5CF6),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Color _accentForRank(int rank) {
    if (rank == 1) return const Color(0xFFC99A3B);
    if (rank == 2) return const Color(0xFF8C5CF6);
    if (rank == 3) return const Color(0xFFE84C72);
    return const Color(0xFF12C7B7);
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final lower = mode.toLowerCase();
    final color = lower.contains('lock')
        ? const Color(0xFFC99A3B)
        : lower.contains('secret')
            ? const Color(0xFF4A2A63)
            : lower.contains('member')
                ? const Color(0xFF8C5CF6)
                : const Color(0xFF12C7B7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        mode,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF7B6A86)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
