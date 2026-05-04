import 'package:flutter/material.dart';

import 'experience_level_models.dart';

class ExperienceLevelPill extends StatelessWidget {
  const ExperienceLevelPill({
    super.key,
    required this.type,
    required this.level,
    this.compact = false,
    this.onTap,
  });

  final ExperienceLevelType type;
  final int level;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final safeLevel = level.clamp(1, 200);
    final style = experiencePillStyleFor(type: type, level: safeLevel);

    final pill = Container(
      height: compact ? 22 : 30,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: style.gradient,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: style.glowColor.withValues(alpha: safeLevel >= 50 ? 0.34 : 0.20),
            blurRadius: safeLevel >= 150 ? 18 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: -18,
              top: -18,
              bottom: -18,
              child: Transform.rotate(
                angle: -0.45,
                child: Container(
                  width: compact ? 16 : 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: safeLevel >= 100 ? 0.52 : 0.34),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(style.crownIcon, color: style.crownColor, size: compact ? 12 : 15),
                SizedBox(width: compact ? 3 : 5),
                Text(
                  '${type.shortLabel} Lv $safeLevel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: style.textColor,
                    fontSize: compact ? 9.4 : 11.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.1,
                    height: 1,
                    shadows: [
                      Shadow(color: Colors.black.withValues(alpha: 0.24), blurRadius: 4),
                      if (safeLevel >= 100) Shadow(color: style.glowColor.withValues(alpha: 0.55), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return pill;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: pill,
      ),
    );
  }
}
