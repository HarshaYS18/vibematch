import 'package:flutter/material.dart';

class EventItem {
  const EventItem({
    required this.id,
    required this.kind,
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
  final String kind;
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
    final now = DateTime.now().toUtc();
    return !now.isBefore(startsAt.toUtc()) && now.isBefore(endsAt.toUtc());
  }
}

class SocialMissionItem {
  const SocialMissionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.requiredCount,
    required this.rewardCoins,
    required this.completed,
    required this.claimed,
    required this.claimable,
  });

  final String id;
  final String title;
  final String description;
  final int progress;
  final int requiredCount;
  final int rewardCoins;
  final bool completed;
  final bool claimed;
  final bool claimable;
}

class CommunityEventsData {
  const CommunityEventsData({
    required this.events,
    required this.missions,
  });

  final List<EventItem> events;
  final List<SocialMissionItem> missions;
}
