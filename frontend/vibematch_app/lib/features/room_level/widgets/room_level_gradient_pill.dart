import 'package:flutter/material.dart';

class RoomLevelGradientPill extends StatelessWidget {
  const RoomLevelGradientPill({
    super.key,
    required this.level,
    required this.label,
    required this.colors,
    this.compact = false,
  });

  final int level;
  final String label;
  final List<Color> colors;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.22),
            blurRadius: compact ? 10 : 16,
            offset: Offset(0, compact ? 4 : 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: Colors.white,
            size: compact ? 13 : 16,
          ),
          const SizedBox(width: 5),
          Text(
            'Room Lv $level',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 7),
            Container(
              width: 1,
              height: 14,
              color: Colors.white.withValues(alpha: 0.28),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
