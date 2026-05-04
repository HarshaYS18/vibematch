import 'package:flutter/material.dart';

class EventItem {
  const EventItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.rewardText,
    required this.startsAt,
    required this.endsAt,
    required this.fallbackIcon,
    required this.gradient,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String status;
  final String rewardText;
  final DateTime startsAt;
  final DateTime endsAt;
  final IconData fallbackIcon;
  final List<Color> gradient;
  final String? imageUrl;

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startsAt) && now.isBefore(endsAt);
  }
}
