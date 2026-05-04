import 'package:flutter/material.dart';

class HomeBanner {
  final String id;
  final String title;
  final String? imageUrl;
  final IconData fallbackIcon;
  final List<Color> fallbackGradient;

  const HomeBanner({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.fallbackIcon,
    required this.fallbackGradient,
  });
}
