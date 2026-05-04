import 'package:flutter/material.dart';

import '../models/social_user.dart';

class SocialMockData {
  const SocialMockData._();

  static const List<SocialUser> users = [
    SocialUser(
      id: 'riya',
      displayName: 'Riya',
      username: 'riya',
      avatarText: 'R',
      colors: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      isOnline: true,
      isFollowing: true,
      isFollower: true,
    ),
    SocialUser(
      id: 'akhil',
      displayName: 'Akhil',
      username: 'akhil',
      avatarText: 'A',
      colors: [Color(0xFFE84C72), Color(0xFFC99A3B)],
      isOnline: true,
      isFollowing: true,
      isFollower: true,
    ),
    SocialUser(
      id: 'founder',
      displayName: 'Founder',
      username: 'founder',
      avatarText: 'F',
      colors: [Color(0xFFFFC857), Color(0xFF8C5CF6)],
      isOnline: true,
      isFollowing: false,
      isFollower: true,
    ),
    SocialUser(
      id: 'meera',
      displayName: 'Meera',
      username: 'meera',
      avatarText: 'M',
      colors: [Color(0xFF8C5CF6), Color(0xFF12C7B7)],
      isOnline: false,
      isFollowing: true,
      isFollower: false,
    ),
    SocialUser(
      id: 'kiran',
      displayName: 'Kiran',
      username: 'kiran',
      avatarText: 'K',
      colors: [Color(0xFFC99A3B), Color(0xFFE84C72)],
      isOnline: false,
      isFollowing: true,
      isFollower: true,
    ),
    SocialUser(
      id: 'nisha',
      displayName: 'Nisha',
      username: 'nisha',
      avatarText: 'N',
      colors: [Color(0xFFE84C72), Color(0xFF8C8198)],
      isOnline: false,
      isFollowing: false,
      isFollower: true,
    ),
  ];

  static List<SocialUser> get following => users.where((user) => user.isFollowing).toList();
  static List<SocialUser> get followers => users.where((user) => user.isFollower).toList();
  static List<SocialUser> get friends => users.where((user) => user.isFriend).toList();

  static bool isValidMention(String token) {
    final clean = token.toLowerCase().replaceFirst('@', '').trim();
    if (clean == 'all') return true;
    return users.any((user) => user.username.toLowerCase() == clean);
  }
}
