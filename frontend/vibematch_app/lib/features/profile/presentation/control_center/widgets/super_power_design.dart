import 'package:flutter/material.dart';

class SuperPowerDesign {
  const SuperPowerDesign._();

  static const Color bg = Color(0xFF02040A);
  static const Color obsidian = Color(0xFF080B14);
  static const Color panel = Color(0xFF101522);
  static const Color panelSoft = Color(0xFF151B2C);
  static const Color stroke = Color(0xFF26324D);
  static const Color gold = Color(0xFFFFD36A);
  static const Color rose = Color(0xFFFF4F8B);
  static const Color violet = Color(0xFF9A70FF);
  static const Color aqua = Color(0xFF3FE8FF);
  static const Color mint = Color(0xFF42F5B7);
  static const Color muted = Color(0xFFA9B3CC);
  static const Color text = Colors.white;

  static const LinearGradient commandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF17233A), Color(0xFF090D17), Color(0xFF120A1C)],
    stops: [0.0, 0.58, 1.0],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE39A), Color(0xFFFFC34D), Color(0xFF9F6C13)],
  );

  static BoxDecoration shell({double radius = 22, Color? color, Color? borderColor}) {
    return BoxDecoration(
      gradient: color == null ? commandGradient : null,
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? stroke.withValues(alpha: 0.92)),
      boxShadow: [
        BoxShadow(color: aqua.withValues(alpha: 0.045), blurRadius: 22, offset: const Offset(-8, -4)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.42), blurRadius: 28, offset: const Offset(0, 16)),
      ],
    );
  }

  static BoxDecoration glowShell({double radius = 28}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF24365B), Color(0xFF090D18), Color(0xFF1D0D24)]),
      border: Border.all(color: Color(0x77FFD36A)),
      boxShadow: [
        BoxShadow(color: gold.withValues(alpha: 0.12), blurRadius: 34, offset: const Offset(0, 16)),
        BoxShadow(color: aqua.withValues(alpha: 0.08), blurRadius: 26, offset: const Offset(-12, -8)),
      ],
    );
  }

  static BoxDecoration glassStrip({required Color accent}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [accent.withValues(alpha: 0.16), const Color(0xFF0A0E18), const Color(0xFF111525)],
        stops: const [0.0, 0.38, 1.0],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: accent.withValues(alpha: 0.35)),
      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.055), blurRadius: 18, offset: const Offset(0, 8))],
    );
  }

  static String compactCoins(int value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}
