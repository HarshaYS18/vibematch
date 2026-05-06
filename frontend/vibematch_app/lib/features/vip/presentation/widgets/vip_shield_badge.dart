import 'package:flutter/material.dart';

class VipShieldBadge extends StatelessWidget {
  const VipShieldBadge({
    super.key,
    required this.level,
    this.size = 58,
  });

  final int level;
  final double size;

  static const String _assetBase = 'assets/images/vip_badges';

  int get _safeLevel => level.clamp(0, 50).toInt();

  String get _assetPath {
    if (_safeLevel >= 41) return '$_assetBase/vip_purple.png';
    if (_safeLevel >= 30) return '$_assetBase/vip_green.png';
    if (_safeLevel >= 21) return '$_assetBase/vip_blue.png';
    if (_safeLevel >= 11) return '$_assetBase/vip_red.png';
    if (_safeLevel >= 6) return '$_assetBase/vip_black_gold.png';
    return '$_assetBase/vip_silver.png';
  }

  Color get _glowColor {
    if (_safeLevel >= 41) return const Color(0xFFD65AFF);
    if (_safeLevel >= 30) return const Color(0xFF20FF99);
    if (_safeLevel >= 21) return const Color(0xFF27B7FF);
    if (_safeLevel >= 11) return const Color(0xFFFF4D5D);
    if (_safeLevel >= 6) return const Color(0xFFFFC64C);
    return const Color(0xFFDDE1E8);
  }

  @override
  Widget build(BuildContext context) {
    final shineSize = size * 0.38;

    return SizedBox(
      width: size + 18,
      height: size + 18,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _glowColor.withValues(alpha: _safeLevel >= 30 ? 0.62 : 0.42),
                  blurRadius: _safeLevel >= 30 ? 34 : 26,
                  spreadRadius: _safeLevel >= 30 ? 4 : 2,
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.20),
                  blurRadius: 14,
                  spreadRadius: -3,
                  offset: const Offset(-3, -4),
                ),
              ],
            ),
            child: Image.asset(
              _assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_glowColor.withValues(alpha: 0.92), const Color(0xFF251538)],
                    ),
                    border: Border.all(color: const Color(0xFFFFD36A), width: 1.4),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: Colors.white),
                );
              },
            ),
          ),
          Positioned(
            left: size * 0.16,
            top: size * 0.10,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.55,
                child: Container(
                  width: shineSize,
                  height: shineSize * 0.24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.78),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.35),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: size * 0.05,
            top: size * 0.04,
            child: IgnorePointer(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white.withValues(alpha: _safeLevel >= 30 ? 0.92 : 0.72),
                size: size * 0.22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
