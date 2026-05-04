import 'package:flutter/material.dart';

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
                  Color(0xFF05030D),
                  Color(0xFF140520),
                  Color(0xFF22103E),
                  Color(0xFF090611),
                  Color(0xFF030208),
                ],
                stops: [0.0, 0.22, 0.46, 0.74, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -92,
            left: -100,
            right: -100,
            height: 320,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.34),
                    radius: 0.88,
                    colors: [
                      const Color(0xFF8C5CF6).withValues(alpha: 0.34),
                      const Color(0xFF5F2EEA).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -100,
            right: -100,
            height: 260,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomCenter,
                    radius: 0.90,
                    colors: [
                      const Color(0xFF0FC7B7).withValues(alpha: 0.13),
                      const Color(0xFF8C5CF6).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.04),
                  const Color(0xFF10051E).withValues(alpha: 0.18),
                  const Color(0xFF080612).withValues(alpha: 0.56),
                  const Color(0xFF04030A).withValues(alpha: 0.92),
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
