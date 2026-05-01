import 'package:flutter/material.dart';

import '../models/home_category_model.dart';
import '../models/home_highlight_model.dart';
import '../models/home_room_model.dart';

class HomeMockData {
  const HomeMockData._();

  static const categories = <HomeCategoryModel>[
    HomeCategoryModel(title: 'Trending'),
    HomeCategoryModel(title: 'Following'),
    HomeCategoryModel(title: 'Music'),
    HomeCategoryModel(title: 'Gaming'),
    HomeCategoryModel(title: 'Chat'),
    HomeCategoryModel(title: 'PK'),
  ];

  static const languages = <String>[
    'All',
    'Telugu',
    'Hindi',
    'English',
    'Tamil',
    'Malayalam',
    'Kannada',
    'Bengali',
    'Marathi',
    'Punjabi',
    'Gujarati',
    'Odia',
    'Urdu',
    'Arabic',
    'Spanish',
    'French',
    'Other',
  ];

  static const highlights = <HomeHighlightModel>[
    HomeHighlightModel(
      title: 'Tonight’s Premium Rooms',
      subtitle: 'Join trending voice rooms with live seats and gifts.',
      icon: Icons.graphic_eq_rounded,
      gradient: [Color(0xFF12C7B7), Color(0xFF8C5CF6), Color(0xFFE84C72)],
    ),
    HomeHighlightModel(
      title: 'Vibe Sync Rooms',
      subtitle: 'Music-style live rooms with animated mood and energy.',
      icon: Icons.waves_rounded,
      gradient: [Color(0xFF251538), Color(0xFF4A2A63), Color(0xFF12C7B7)],
    ),
    HomeHighlightModel(
      title: 'Official Events',
      subtitle: 'Events are available through banners and inbox updates.',
      icon: Icons.workspace_premium_rounded,
      gradient: [Color(0xFFC99A3B), Color(0xFFE84C72), Color(0xFF4A2A63)],
    ),
  ];

  static const rooms = <HomeRoomModel>[
    HomeRoomModel(id: 'VM120451', name: 'Late Night Chill', subtitle: 'Soft talks, music and Telugu vibes', language: 'Telugu', mode: 'Open', type: 'Music', onlineCount: 248, trendingScore: 9820, followedFriendsInside: ['Riya', 'Aman']),
    HomeRoomModel(id: 'VM881029', name: 'Hyderabad Friends Adda', subtitle: 'Casual chat room for Telugu friends', language: 'Telugu', mode: 'Locked', type: 'Chat', onlineCount: 186, trendingScore: 8740, followedFriendsInside: ['Meera']),
    HomeRoomModel(id: 'VM772190', name: 'Secret Star Vibe', subtitle: 'Private hidden room', language: 'Hindi', mode: 'Secret Vibe', type: 'Chat', onlineCount: 91, trendingScore: 8321, followedFriendsInside: ['Kiran']),
    HomeRoomModel(id: 'VM551482', name: 'Bollywood Vibe Sync', subtitle: 'Hindi songs, live energy and gifts', language: 'Hindi', mode: 'Vibe Sync', type: 'Music', onlineCount: 452, trendingScore: 12940, followedFriendsInside: ['Riya', 'Kiran', 'Aman']),
    HomeRoomModel(id: 'VM660410', name: 'English Talk Lounge', subtitle: 'Practice English and meet new friends', language: 'English', mode: 'Open', type: 'Chat', onlineCount: 129, trendingScore: 6540, followedFriendsInside: []),
    HomeRoomModel(id: 'VM330821', name: 'Tamil Melody Room', subtitle: 'Tamil songs and friendly talks', language: 'Tamil', mode: 'Open', type: 'Music', onlineCount: 214, trendingScore: 7360, followedFriendsInside: ['Meera']),
    HomeRoomModel(id: 'VM909112', name: 'Gaming Voice Squad', subtitle: 'Find teammates and game friends', language: 'English', mode: 'Open', type: 'Gaming', onlineCount: 318, trendingScore: 9102, followedFriendsInside: ['Aman']),
    HomeRoomModel(id: 'VM741902', name: 'Malayalam Friends Cafe', subtitle: 'Friendly Malayalam room', language: 'Malayalam', mode: 'Members Only', type: 'Chat', onlineCount: 104, trendingScore: 5121, followedFriendsInside: ['Nivin']),
    HomeRoomModel(id: 'VM624812', name: 'PK Battle Arena', subtitle: 'Voice room with PK-style energy', language: 'Hindi', mode: 'Open', type: 'PK', onlineCount: 502, trendingScore: 15420, followedFriendsInside: ['Riya']),
    HomeRoomModel(id: 'VM882761', name: 'Kannada Chill House', subtitle: 'Late night Kannada live room', language: 'Kannada', mode: 'Locked', type: 'Chat', onlineCount: 88, trendingScore: 3980, followedFriendsInside: ['Kavya']),
    HomeRoomModel(id: 'VM771541', name: 'Bengali Music Night', subtitle: 'Songs, poems and friendly voices', language: 'Bengali', mode: 'Vibe Sync', type: 'Music', onlineCount: 176, trendingScore: 6891, followedFriendsInside: ['Kiran']),
    HomeRoomModel(id: 'VM445129', name: 'Friends Only Lounge', subtitle: 'Private member-based talk room', language: 'English', mode: 'Members Only', type: 'Chat', onlineCount: 67, trendingScore: 2870, followedFriendsInside: ['Meera']),
  ];
}
