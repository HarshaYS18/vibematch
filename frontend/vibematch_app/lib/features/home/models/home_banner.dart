import 'package:flutter/material.dart';

class HomeBanner {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final HomeBannerAction action;

  const HomeBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.action,
  });
}

enum HomeBannerAction {
  openEvents,
  openTrendingRooms,
  openVibeSyncRooms,
}
