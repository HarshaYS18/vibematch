import 'package:flutter/material.dart';

class SocialUser {
  const SocialUser({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarText,
    required this.colors,
    this.isOnline = false,
    this.isFollowing = false,
    this.isFollower = false,
  });

  final String id;
  final String displayName;
  final String username;
  final String avatarText;
  final List<Color> colors;
  final bool isOnline;
  final bool isFollowing;
  final bool isFollower;

  bool get isFriend => isFollowing && isFollower;

  String get mentionToken => username.trim().isEmpty ? displayName : username;
}
