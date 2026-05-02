import 'package:flutter/material.dart';

import '../room_theme.dart';

class LiveRoomVipLevelBadge extends StatelessWidget {
  const LiveRoomVipLevelBadge({
    super.key,
    required this.vipLevel,
    this.compact = false,
  });

  final int vipLevel;
  final bool compact;

  bool get _visible => vipLevel > 0;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final palette = _VipLevelPalette.forLevel(vipLevel);
    final badgeSize = compact ? 16.0 : 18.0;
    final pillHeight = compact ? 15.0 : 17.0;
    final pillPaddingLeft = compact ? 12.0 : 13.5;
    final pillPaddingRight = compact ? 6.0 : 7.0;

    return RepaintBoundary(
      child: Semantics(
        label: 'VIP level $vipLevel',
        child: SizedBox(
          height: badgeSize,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: pillHeight,
                margin: EdgeInsets.only(left: badgeSize * 0.48),
                padding: EdgeInsets.only(
                  left: pillPaddingLeft,
                  right: pillPaddingRight,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: palette.pillColors),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 0.7,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.glowColor.withValues(alpha: 0.24),
                      blurRadius: compact ? 5 : 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$vipLevel',
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 8.2 : 9.2,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.15,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: badgeSize,
                height: badgeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: palette.badgeColors,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                    width: compact ? 0.8 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.glowColor.withValues(alpha: 0.35),
                      blurRadius: compact ? 5 : 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: compact ? 9.2 : 10.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VipLevelPalette {
  const _VipLevelPalette({
    required this.badgeColors,
    required this.pillColors,
    required this.glowColor,
  });

  final List<Color> badgeColors;
  final List<Color> pillColors;
  final Color glowColor;

  static _VipLevelPalette forLevel(int level) {
    if (level >= 21) {
      return const _VipLevelPalette(
        badgeColors: [Color(0xFFFFF0A3), RoomColors.gold],
        pillColors: [Color(0xFFC47D19), Color(0xFFFFC857)],
        glowColor: RoomColors.gold,
      );
    }

    if (level >= 11) {
      return const _VipLevelPalette(
        badgeColors: [Color(0xFFFF8BA3), RoomColors.coral],
        pillColors: [Color(0xFFB92E58), Color(0xFFE84C72)],
        glowColor: RoomColors.coral,
      );
    }

    return const _VipLevelPalette(
      badgeColors: [Color(0xFF61F2D7), RoomColors.aqua],
      pillColors: [Color(0xFF078E87), Color(0xFF12C7B7)],
      glowColor: RoomColors.aqua,
    );
  }
}
