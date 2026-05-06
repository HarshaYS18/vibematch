import 'package:flutter/material.dart';

import '../models/vibe_models.dart';

class VibesMockData {
  const VibesMockData._();

  static const List<VibeItem> vibes = [
    VibeItem(
      id: 'vibe_founder_001',
      authorName: 'Founder',
      authorId: '6922022',
      avatarText: 'F',
      timeAgo: '2m ago',
      mediaType: VibeMediaType.photo,
      caption: 'Building the new Vibe Match Vibes page. Photos, videos, comments and mentions are coming together. @all',
      tag: 'Update',
      likes: 1280,
      comments: 86,
      shares: 19,
      views: 12500,
      isFollowing: true,
      usesMentionAll: true,
      mentions: [],
      colors: [Color(0xFF6D5DF6), Color(0xFFE84C72)],
    ),
    VibeItem(
      id: 'vibe_akhil_002',
      authorName: 'Akhil',
      authorId: '6418008421',
      avatarText: 'A',
      timeAgo: '18m ago',
      mediaType: VibeMediaType.video,
      caption: 'Late Night Chill room was crazy today 🔥 thanks @riya and @founder for joining.',
      tag: 'Room',
      likes: 846,
      comments: 42,
      shares: 11,
      views: 8200,
      isFollowing: true,
      usesMentionAll: false,
      mentions: ['Riya', 'Founder'],
      colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    ),
    VibeItem(
      id: 'vibe_meera_003',
      authorName: 'Meera',
      authorId: '6418004771',
      avatarText: 'M',
      timeAgo: '1h ago',
      mediaType: VibeMediaType.text,
      caption: 'A clean profile should show identity clearly: bio, age, gender, interests, VIP/SVIP, CP, Vibes and presence.',
      tag: 'Design',
      likes: 2400,
      comments: 171,
      shares: 44,
      views: 24000,
      isFollowing: false,
      usesMentionAll: false,
      mentions: [],
      colors: [Color(0xFFC99A3B), Color(0xFFE84C72)],
    ),
  ];

  static const List<VibeComment> comments = [
    VibeComment(name: 'Riya', avatarText: 'R', text: 'This looks premium 🔥 @founder', time: '2m ago'),
    VibeComment(name: 'Akhil', avatarText: 'A', text: 'Need this in live rooms too!', time: '5m ago'),
  ];
}
