import 'package:flutter/material.dart';

import 'room_theme.dart';

enum VipBadgeSize { tiny, small, medium, large }

class VipBadge extends StatelessWidget {
  const VipBadge({
    super.key,
    required this.level,
    this.size = VipBadgeSize.small,
    this.onTap,
    this.showWhenZero = false,
  });

  final int level;
  final VipBadgeSize size;
  final VoidCallback? onTap;
  final bool showWhenZero;

  static const String _assetBase = 'assets/images/vip_badges';

  bool get _visible => level > 0 || showWhenZero;

  int get _safeLevel => level.clamp(0, 50);

  String get _assetPath {
    final value = _safeLevel;
    if (value <= 10) return '$_assetBase/vip_emerald_1_10.png';
    if (value <= 20) return '$_assetBase/vip_purple_11_20.png';
    if (value <= 30) return '$_assetBase/vip_crimson_21_30.png';
    if (value <= 40) return '$_assetBase/vip_diamond_31_40.png';
    return '$_assetBase/vip_mythic_41_50.png';
  }

  Color get _fallbackStart {
    final value = _safeLevel;
    if (value <= 10) return const Color(0xFF009B56);
    if (value <= 20) return const Color(0xFF5B16B8);
    if (value <= 30) return const Color(0xFFC30022);
    if (value <= 40) return const Color(0xFF006FEA);
    return const Color(0xFF080808);
  }

  Color get _fallbackEnd {
    final value = _safeLevel;
    if (value <= 10) return const Color(0xFF00E676);
    if (value <= 20) return const Color(0xFFB347FF);
    if (value <= 30) return const Color(0xFFFF1744);
    if (value <= 40) return const Color(0xFF00B0FF);
    return const Color(0xFFFFC857);
  }

  double get _width {
    switch (size) {
      case VipBadgeSize.tiny:
        return 50;
      case VipBadgeSize.small:
        return 62;
      case VipBadgeSize.medium:
        return 82;
      case VipBadgeSize.large:
        return 112;
    }
  }

  double get _height {
    switch (size) {
      case VipBadgeSize.tiny:
        return 22;
      case VipBadgeSize.small:
        return 28;
      case VipBadgeSize.medium:
        return 38;
      case VipBadgeSize.large:
        return 52;
    }
  }

  double get _fontSize {
    switch (size) {
      case VipBadgeSize.tiny:
        return 8.5;
      case VipBadgeSize.small:
        return 10;
      case VipBadgeSize.medium:
        return 13;
      case VipBadgeSize.large:
        return 17;
    }
  }

  EdgeInsets get _textPadding {
    switch (size) {
      case VipBadgeSize.tiny:
        return const EdgeInsets.only(top: 2);
      case VipBadgeSize.small:
        return const EdgeInsets.only(top: 3);
      case VipBadgeSize.medium:
        return const EdgeInsets.only(top: 4);
      case VipBadgeSize.large:
        return const EdgeInsets.only(top: 6);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final child = SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Image.asset(
            _assetPath,
            fit: BoxFit.fill,
            errorBuilder: (context, error, stackTrace) => _FallbackBadge(
              start: _fallbackStart,
              end: _fallbackEnd,
            ),
          ),
          Padding(
            padding: _textPadding,
            child: Center(
              child: Text(
                'VIP $_safeLevel',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _fontSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.1,
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                    Shadow(color: RoomColors.gold, blurRadius: 7),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class _FallbackBadge extends StatelessWidget {
  const _FallbackBadge({required this.start, required this.end});

  final Color start;
  final Color end;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: [start, end]),
        border: Border.all(color: RoomColors.gold, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: end.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}