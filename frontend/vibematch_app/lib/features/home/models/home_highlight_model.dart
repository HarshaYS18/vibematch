import 'package:flutter/material.dart';

class HomeHighlightModel {
  const HomeHighlightModel({
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
