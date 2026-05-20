import 'package:flutter/material.dart';

class InboxLightPremiumTokens {
  const InboxLightPremiumTokens._();

  static const Color page = Color(0xFFFFFBFF);
  static const Color pearl = Color(0xFFFAF7F1);
  static const Color card = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF19102B);
  static const Color muted = Color(0xFF7B6A86);
  static const Color softMuted = Color(0xFFA093AD);
  static const Color violet = Color(0xFF8C5CF6);
  static const Color violetDeep = Color(0xFF6D5DF6);
  static const Color pink = Color(0xFFFF4F9A);
  static const Color aqua = Color(0xFF12C7B7);
  static const Color gold = Color(0xFFC99A3B);
  static const Color warning = Color(0xFFFFB020);
  static const Color danger = Color(0xFFE84C72);
  static const Color border = Color(0xFFECE2F5);
  static const Color warmBorder = Color(0xFFECE2D8);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [pink, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aquaGradient = LinearGradient(
    colors: [aqua, violetDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pageGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF8FF), Color(0xFFF8F7FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static BoxShadow softShadow([double alpha = 0.06]) => BoxShadow(
        color: ink.withValues(alpha: alpha),
        blurRadius: 20,
        offset: const Offset(0, 10),
      );

  static BoxDecoration cardDecoration({Color? borderColor, double radius = 24}) => BoxDecoration(
        color: card.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? border),
        boxShadow: [softShadow()],
      );
}
