import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.purple,
      secondary: AppColors.pink,
      surface: AppColors.card,
    ),
    useMaterial3: true,
    fontFamily: 'Roboto',
  );
}