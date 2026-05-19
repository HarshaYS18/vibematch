import 'package:flutter/material.dart';

class GiftVisual extends StatelessWidget {
  const GiftVisual({
    super.key,
    required this.icon,
    required this.colors,
    this.assetPath,
    this.assetUrl,
    this.size = 36,
    this.padding = 5,
    this.square = false,
  });

  final IconData icon;
  final List<Color> colors;
  final String? assetPath;
  final String? assetUrl;
  final double size;
  final double padding;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = assetUrl?.trim();
    final cleanPath = assetPath?.trim();
    final visualSize = size - padding;

    final Widget visual = cleanUrl != null && cleanUrl.isNotEmpty
        ? Image.network(
            cleanUrl,
            width: visualSize,
            height: visualSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                _localOrIcon(cleanPath, visualSize),
          )
        : _localOrIcon(cleanPath, visualSize);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(14) : null,
        gradient: LinearGradient(colors: colors),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.34),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: size * 0.38,
            offset: Offset(0, size * 0.12),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.16),
            blurRadius: size * 0.22,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(square ? 13 : size / 2),
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
            visual,
          ],
        ),
      ),
    );
  }

  Widget _localOrIcon(String? cleanPath, double visualSize) {
    if (cleanPath == null || cleanPath.isEmpty) return _iconFallback();
    return Image.asset(
      cleanPath,
      width: visualSize,
      height: visualSize,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => _iconFallback(),
    );
  }

  Widget _iconFallback() {
    return Icon(icon, color: Colors.white, size: size * 0.46);
  }
}
