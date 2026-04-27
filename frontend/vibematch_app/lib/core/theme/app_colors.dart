import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF8F6F2);
  static const Color card = Colors.white;

  static const Color coral = Color(0xFFFF6B4A);
  static const Color pink = Color(0xFFE84AAE);
  static const Color purple = Color(0xFF7B4DFF);
  static const Color blue = Color(0xFF4DA3FF);

  static const Color textPrimary = Color(0xFF201A2E);
  static const Color textSecondary = Color(0xFF6B6478);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [
      coral,
      pink,
      purple,
      blue,
    ],
  );
}