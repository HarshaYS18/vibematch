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
          Image.asset(
            RoomRankingsAssets.podiumBackground,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF070512),
                      Color(0xFF10051E),
                      Color(0xFF05030D),
                    ],
                  ),
                ),
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.16),
                  Colors.black.withValues(alpha: 0.42),
                  Colors.black.withValues(alpha: 0.72),
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
