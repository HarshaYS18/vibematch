import 'package:flutter/material.dart';

class HomeBannerData {
  const HomeBannerData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
}
