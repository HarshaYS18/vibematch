import 'package:flutter/material.dart';

import '../models/event_item.dart';

class EventsMockData {
  const EventsMockData._();

  static final List<EventItem> activeEvents = [
    EventItem(
      id: 'event_weekend_001',
      kind: 'rooms',
      title: 'Weekend Voice Party',
      subtitle: 'Join official rooms, send gifts, and collect limited event badges.',
      status: 'Active now',
      rewardText: 'Badges · Free frames · Gift rewards',
      startsAt: DateTime.now().subtract(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 5)),
      fallbackIcon: Icons.celebration_rounded,
      gradient: const [Color(0xFFE84C72), Color(0xFF8C5CF6)],
    ),
    EventItem(
      id: 'event_vibes_001',
      kind: 'missions',
      title: 'Vibes Creator Week',
      subtitle: 'Post Vibes, mention fans, and climb the event activity board.',
      status: 'Active now',
      rewardText: 'Creator badge · Profile frame · Ranking rewards',
      startsAt: DateTime.now().subtract(const Duration(hours: 12)),
      endsAt: DateTime.now().add(const Duration(days: 7)),
      fallbackIcon: Icons.auto_awesome_rounded,
      gradient: const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    ),
    EventItem(
      id: 'promo_recharge_001',
      kind: 'community',
      title: 'Recharge Bonus Promo',
      subtitle: 'Recharge during the promo window and unlock bonus progress.',
      status: 'Active promo',
      rewardText: 'Bonus coins · SVIP progress · Lucky rewards',
      startsAt: DateTime.now().subtract(const Duration(days: 2)),
      endsAt: DateTime.now().add(const Duration(days: 3)),
      fallbackIcon: Icons.bolt_rounded,
      gradient: const [Color(0xFFC99A3B), Color(0xFFE84C72)],
    ),
  ];
}
