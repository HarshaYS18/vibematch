import 'package:flutter/material.dart';

class FamilyClanBadgeIcon extends StatelessWidget {
  const FamilyClanBadgeIcon({
    super.key,
    required this.familyName,
    required this.familyLevel,
    this.size = 96,
  });

  final String familyName;
  final String familyLevel;
  final double size;

  String get _cleanName {
    final clean = familyName.trim();
    if (clean.isEmpty) return 'Family';
    return clean;
  }

  String get _level {
    final raw = familyLevel.trim().toLowerCase();
    if (raw.contains('platinum')) return 'platinum';
    if (raw.contains('gold')) return 'gold';
    if (raw.contains('silver')) return 'silver';
    return 'bronze';
  }

  _BadgeIconStyle get _style {
    switch (_level) {
      case 'platinum':
        return const _BadgeIconStyle(
          assetPath: 'assets/images/family_badges/platinum.png',
          fallbackTop: Color(0xFFEAF0F8),
          fallbackBottom: Color(0xFF7B8594),
          glow: Color(0xFFEAF0F8),
          text: Color(0xFF202A38),
          sparkle: Color(0xFFFFFFFF),
        );
      case 'gold':
        return const _BadgeIconStyle(
          assetPath: 'assets/images/family_badges/gold.png',
          fallbackTop: Color(0xFFFFE28A),
          fallbackBottom: Color(0xFFE0B12F),
          glow: Color(0xFFFFD96A),
          text: Color(0xFF3A2500),
          sparkle: Color(0xFFFFF2B0),
        );
      case 'silver':
        return const _BadgeIconStyle(
          assetPath: 'assets/images/family_badges/silver.png',
          fallbackTop: Color(0xFFF0F4F8),
          fallbackBottom: Color(0xFF9AA5B1),
          glow: Color(0xFFD6DDE5),
          text: Color(0xFF2C3440),
          sparkle: Color(0xFFFFFFFF),
        );
      default:
        return const _BadgeIconStyle(
          assetPath: 'assets/images/family_badges/bronze.png',
          fallbackTop: Color(0xFFDCA477),
          fallbackBottom: Color(0xFFC08A5A),
          glow: Color(0xFFC68E61),
          text: Color(0xFF3A1F10),
          sparkle: Color(0xFFFFD8BA),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return SizedBox(
      width: size + 18,
      height: size + 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size + 10,
            height: size + 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [style.glow.withValues(alpha: 0.34), style.glow.withValues(alpha: 0.04), Colors.transparent]),
            ),
          ),
          Container(
            width: size + 2,
            height: size + 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: style.sparkle.withValues(alpha: 0.46), width: 1.1),
              boxShadow: [BoxShadow(color: style.glow.withValues(alpha: 0.36), blurRadius: 24, spreadRadius: 1)],
            ),
          ),
          Image.asset(
            style.assetPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [style.fallbackTop, style.fallbackBottom]),
                  border: Border.all(color: style.sparkle.withValues(alpha: 0.70), width: 1.2),
                  boxShadow: [BoxShadow(color: style.glow.withValues(alpha: 0.34), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Center(
                  child: Text(
                    _cleanName.characters.first.toUpperCase(),
                    style: TextStyle(color: style.text, fontSize: size * 0.44, fontWeight: FontWeight.w900),
                  ),
                ),
              );
            },
          ),
          Positioned(top: 6, right: 12, child: _Sparkle(color: style.sparkle, size: size * 0.15)),
          Positioned(bottom: 12, left: 10, child: _Sparkle(color: style.sparkle.withValues(alpha: 0.70), size: size * 0.10)),
        ],
      ),
    );
  }
}

class _BadgeIconStyle {
  const _BadgeIconStyle({
    required this.assetPath,
    required this.fallbackTop,
    required this.fallbackBottom,
    required this.glow,
    required this.text,
    required this.sparkle,
  });

  final String assetPath;
  final Color fallbackTop;
  final Color fallbackBottom;
  final Color glow;
  final Color text;
  final Color sparkle;
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.auto_awesome_rounded, color: color, size: size);
  }
}
