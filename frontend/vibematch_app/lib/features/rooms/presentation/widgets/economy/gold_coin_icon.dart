import 'package:flutter/material.dart';

class GoldCoinIcon extends StatelessWidget {
  const GoldCoinIcon({
    super.key,
    this.size = 14,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.35, -0.35),
            radius: 0.92,
            colors: [
              Color(0xFFFFF3A3),
              Color(0xFFFFD166),
              Color(0xFFE9A928),
              Color(0xFF9B6712),
            ],
            stops: [0.0, 0.36, 0.72, 1.0],
          ),
          border: Border.all(color: const Color(0xFFFFF0A8), width: size * 0.07),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD166).withValues(alpha: 0.36),
              blurRadius: size * 0.45,
              offset: Offset(0, size * 0.14),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: size * 0.48,
            height: size * 0.48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFF5B8).withValues(alpha: 0.72), width: size * 0.045),
            ),
            child: Icon(
              Icons.star_rounded,
              color: const Color(0xFFFFF7C2),
              size: size * 0.28,
            ),
          ),
        ),
      ),
    );
  }
}
