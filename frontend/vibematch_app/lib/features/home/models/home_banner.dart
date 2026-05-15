import 'package:flutter/material.dart';

class HomeBanner {
  final String id;
  final String title;
  final String? imageUrl;
  final String placement;
  final String target;
  final String? targetUrl;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final IconData fallbackIcon;
  final List<Color> fallbackGradient;

  const HomeBanner({
    required this.id,
    required this.title,
    this.imageUrl,
    this.placement = 'event',
    this.target = 'event',
    this.targetUrl,
    this.description,
    this.sortOrder = 1,
    this.isActive = true,
    required this.fallbackIcon,
    required this.fallbackGradient,
  });
}
