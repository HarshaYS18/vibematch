import 'package:flutter/material.dart';

import 'room_rankings_assets.dart';

class RoomRankingsBackground extends StatelessWidget {
  const RoomRankingsBackground({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF070512),
                  Color(0xFF16052A),
                  Color(0xFF0A0614),
                  Color(0xFF04030A),
                ],
              ),
            ),
          ),
          Positioned.fill(
            top: -34,
            bottom: 26,
            child: Transform.scale(
              scale: 0.92,
              alignment: Alignment.topCenter,
              child: Image.asset(
                RoomRankingsAssets.podiumBackground,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  const Color(0xFF10051E).withValues(alpha: 0.20),
                  const Color(0xFF080612).withValues(alpha: 0.66),
                  const Color(0xFF04030A).withValues(alpha: 0.90),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
