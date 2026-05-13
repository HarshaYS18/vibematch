import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'room_theme.dart';

class LiveRoomGamesSheet extends StatelessWidget {
  const LiveRoomGamesSheet({
    super.key,
    required this.onGalacticSpinsTap,
  });

  final VoidCallback onGalacticSpinsTap;

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
          const Text(
            'Room games available for MVP testing',
            style: TextStyle(
              color: RoomColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _GalacticSpinsGameCard(onTap: onGalacticSpinsTap),
        ],
      ),
    );
  }
}

class _GalacticSpinsGameCard extends StatelessWidget {
  const _GalacticSpinsGameCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF101A3A),
              Color(0xFF251052),
              Color(0xFF101A3A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFFFD76A), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFC857).withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF070B1B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF38E8FF).withValues(alpha: 0.65),
                ),
              ),
              child: SvgPicture.asset(
                'assets/images/games/galactic_spins/symbols/symbol_wild_star.svg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Galactic Spins',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Slot-style test game with backend economy route',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFC8D5FF),
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD76A),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD76A).withValues(alpha: 0.28),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFF251052),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
