import 'package:flutter/material.dart';

class SuperPowerDesign {
  const SuperPowerDesign._();

  static const Color bg = Color(0xFF05030A);
  static const Color obsidian = Color(0xFF0C0614);
  static const Color panel = Color(0xFF15101F);
  static const Color panelSoft = Color(0xFF1D142A);
  static const Color stroke = Color(0xFF352846);
  static const Color gold = Color(0xFFFFD36A);
  static const Color rose = Color(0xFFFF5D8F);
  static const Color violet = Color(0xFF8A5CFF);
  static const Color aqua = Color(0xFF45E5FF);
  static const Color mint = Color(0xFF3BF2B4);
  static const Color muted = Color(0xFFB0A5BC);
  static const Color text = Colors.white;

  static BoxDecoration shell({double radius = 22, Color? color, Color? borderColor}) {
    return BoxDecoration(
      color: color ?? panel,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? stroke),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 20, offset: const Offset(0, 10))],
    );
  }

  static BoxDecoration glowShell({double radius = 28}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF26163A), Color(0xFF09050F)]),
      border: Border.all(color: Color(0x55FFD36A)),
      boxShadow: [BoxShadow(color: gold.withValues(alpha: 0.10), blurRadius: 30, offset: const Offset(0, 16))],
    );
  }

  static String compactCoins(int value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)}B';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}
