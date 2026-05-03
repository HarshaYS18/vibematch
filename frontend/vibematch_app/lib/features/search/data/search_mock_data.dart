import 'package:flutter/material.dart';

import '../models/search_result_item.dart';
import '../models/search_result_type.dart';

class SearchMockData {
  const SearchMockData._();

  static const List<String> recentSearches = [
    'Late Night Chill',
    'Founder',
    'Telugu rooms',
    'Vibe Sync',
  ];

  static const List<String> topSearches = [
    'Late Night Chill',
    'Vibe Sync',
    'Telugu music',
    'Gaming rooms',
    'Founder',
    'PK Battle',
    'Hyderabad friends',
    'Love vibes',
  ];

  static const List<SearchResultItem> results = [
    SearchResultItem(
      type: SearchResultType.user,
      title: 'Founder',
      subtitle: 'ID 6922022 · Founder Owner · Official',
      tag: 'User',
      icon: Icons.verified_user_rounded,
      color: Color(0xFFFFC857),
      keywords: ['founder', 'owner', 'official', '6922022', 'admin'],
    ),
    SearchResultItem(
      type: SearchResultType.user,
      title: 'Riya',
      subtitle: 'ID 6418001293 · VIP 18 · Music lover',
      tag: 'User',
      icon: Icons.person_rounded,
      color: Color(0xFFE84C72),
      keywords: ['riya', 'music', 'vip', 'user'],
    ),
    SearchResultItem(
      type: SearchResultType.user,
      title: 'Meera',
      subtitle: 'ID 6418004771 · Design vibes · Online',
      tag: 'User',
      icon: Icons.person_rounded,
      color: Color(0xFF8C5CF6),
      keywords: ['meera', 'design', 'online', 'user'],
    ),
    SearchResultItem(
      type: SearchResultType.room,
      title: 'Late Night Chill',
      subtitle: 'VM120451 · Telugu · Open · 248 online',
      tag: 'Room',
      icon: Icons.graphic_eq_rounded,
      color: Color(0xFF12C7B7),
      keywords: ['late', 'night', 'chill', 'telugu', 'music', 'room'],
    ),
    SearchResultItem(
      type: SearchResultType.room,
      title: 'Bollywood Vibe Sync',
      subtitle: 'VM551482 · Hindi · Vibe Sync · 452 online',
      tag: 'Room',
      icon: Icons.waves_rounded,
      color: Color(0xFF6D5DF6),
      keywords: ['bollywood', 'vibe', 'sync', 'hindi', 'music', 'room'],
    ),
    SearchResultItem(
      type: SearchResultType.room,
      title: 'Gaming Voice Squad',
      subtitle: 'VM909112 · English · Gaming · 318 online',
      tag: 'Room',
      icon: Icons.sports_esports_rounded,
      color: Color(0xFF251538),
      keywords: ['gaming', 'voice', 'squad', 'english', 'room'],
    ),
    SearchResultItem(
      type: SearchResultType.room,
      title: 'PK Battle Arena',
      subtitle: 'VM624812 · Hindi · PK · 502 online',
      tag: 'Room',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFE84C72),
      keywords: ['pk', 'battle', 'arena', 'hindi', 'room'],
    ),
    SearchResultItem(
      type: SearchResultType.vibe,
      title: 'Building Vibe Match Vibes',
      subtitle: 'Founder · Photo · 12.5K views · @all',
      tag: 'Vibe',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF6D5DF6),
      keywords: ['building', 'vibe', 'match', 'founder', 'photo', 'all'],
    ),
    SearchResultItem(
      type: SearchResultType.vibe,
      title: 'Late Night Chill was crazy today',
      subtitle: 'Akhil · Video · 8.2K views · mentions Riya',
      tag: 'Vibe',
      icon: Icons.play_circle_fill_rounded,
      color: Color(0xFF12C7B7),
      keywords: ['late', 'night', 'chill', 'akhil', 'video', 'riya'],
    ),
    SearchResultItem(
      type: SearchResultType.vibe,
      title: 'Premium profile design idea',
      subtitle: 'Meera · Text · 24K views · Design',
      tag: 'Vibe',
      icon: Icons.article_rounded,
      color: Color(0xFFC99A3B),
      keywords: ['premium', 'profile', 'design', 'meera', 'text'],
    ),
  ];
}
