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
                  Color(0xFF16052A),
                  Color(0xFF25104B),
                  Color(0xFF0A0614),
                  Color(0xFF04030A),
                ],
                stops: [0.0, 0.22, 0.44, 0.72, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -70,
            left: -80,
            right: -80,
            height: 310,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.28),
                    radius: 0.84,
                    colors: [
                      const Color(0xFF8C5CF6).withValues(alpha: 0.42),
                      const Color(0xFF5F2EEA).withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 28,
            left: 28,
            right: 28,
            child: IgnorePointer(
              child: _GeneratedPodiumBackdrop(),
            ),
          ),
          Positioned(
            top: 24,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 0.92,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      const Color(0xFFB869FF).withValues(alpha: 0.09),
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
                  Colors.black.withValues(alpha: 0.05),
                  const Color(0xFF10051E).withValues(alpha: 0.16),
                  const Color(0xFF080612).withValues(alpha: 0.58),
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

class _GeneratedPodiumBackdrop extends StatelessWidget {
  const _GeneratedPodiumBackdrop();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            left: 8,
            right: 8,
            bottom: 0,
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.04),
                    const Color(0xFF8C5CF6).withValues(alpha: 0.26),
                    Colors.white.withValues(alpha: 0.04),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
          Positioned(
            left: 0,
            bottom: 6,
            child: _PodiumBlock(width: 92, height: 54, label: '2', color: const Color(0xFFB7C2FF)),
          ),
          Positioned(
            bottom: 6,
            child: _PodiumBlock(width: 112, height: 82, label: '1', color: const Color(0xFFFFD166), large: true),
          ),
          Positioned(
            right: 0,
            bottom: 6,
            child: _PodiumBlock(width: 92, height: 48, label: '3', color: const Color(0xFFFF8FA3)),
          ),
        ],
      ),
    );
  }
}

class _PodiumBlock extends StatelessWidget {
  const _PodiumBlock({
    required this.width,
    required this.height,
    required this.label,
    required this.color,
    this.large = false,
  });

  final double width;
  final double height;
  final String label;
  final Color color;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.26),
            const Color(0xFF8C5CF6).withValues(alpha: 0.16),
            Colors.black.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.13),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withValues(alpha: 0.72),
          fontSize: large ? 34 : 26,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
