import 'package:flutter/material.dart';

class GiftVisual extends StatelessWidget {
  const GiftVisual({
    super.key,
    required this.icon,
    required this.colors,
    this.assetPath,
    this.size = 36,
    this.padding = 5,
  });

  final IconData icon;
  final List<Color> colors;
  final String? assetPath;
  final double size;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final visual = assetPath == null
        ? null
        : Image.asset(
            assetPath!,
            width: size - padding,
            height: size - padding,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) => Icon(icon, color: Colors.white, size: size * 0.46),
          );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        border: Border.all(color: Colors.white.withValues(alpha: 0.34), width: 0.9),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: size * 0.38, offset: Offset(0, size * 0.12)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.16), blurRadius: size * 0.22, spreadRadius: 0.5),
        ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.34),
                      Colors.white.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.07),
                    ],
                  ),
                ),
              ),
            ),
            visual ?? Icon(icon, color: Colors.white, size: size * 0.46),
          ],
        ),
      ),
    );
  }
}
