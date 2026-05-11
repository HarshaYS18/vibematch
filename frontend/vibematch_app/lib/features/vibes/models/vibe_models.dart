import 'package:flutter/material.dart';

enum VibeMediaType {
  photo('Photo', Icons.photo_rounded, [Color(0xFF6D5DF6), Color(0xFFE84C72)]),
  video('Video', Icons.play_circle_fill_rounded, [Color(0xFF12C7B7), Color(0xFF6D5DF6)]),
  text('Text', Icons.notes_rounded, [Color(0xFFC99A3B), Color(0xFFE84C72)]);

  const VibeMediaType(this.label, this.icon, this.colors);

  final String label;
  final IconData icon;
  final List<Color> colors;
}

enum VibePrivacyAudience {
  followers('Followers'),
  friends('Friends'),
  none('None');

  const VibePrivacyAudience(this.label);
  final String label;
}

class VibeItem {
  const VibeItem({
    this.id = '',
    required this.authorName,
    required this.authorId,
    required this.avatarText,
    required this.timeAgo,
    required this.mediaType,
    required this.caption,
    required this.tag,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.views,
    required this.isFollowing,
    required this.usesMentionAll,
    required this.mentions,
    required this.colors,
    this.mediaUrl,
    this.likedByMe = false,
  });

  final String id;
  final String authorName;
  final String authorId;
  final String avatarText;
  final String timeAgo;
  final VibeMediaType mediaType;
  final String caption;
  final String tag;
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final bool isFollowing;
  final bool usesMentionAll;
  final List<String> mentions;
  final List<Color> colors;
  final String? mediaUrl;
  final bool likedByMe;

  bool get hasMediaUrl => mediaUrl != null && mediaUrl!.trim().isNotEmpty;

  VibeItem copyWith({
    int? likes,
    int? comments,
    int? shares,
    String? mediaUrl,
    bool? likedByMe,
  }) {
    return VibeItem(
      id: id,
      authorName: authorName,
      authorId: authorId,
      avatarText: avatarText,
      timeAgo: timeAgo,
      mediaType: mediaType,
      caption: caption,
      tag: tag,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views,
      isFollowing: isFollowing,
      usesMentionAll: usesMentionAll,
      mentions: mentions,
      colors: colors,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }
}

class VibeComment {
  const VibeComment({
    required this.name,
    required this.avatarText,
    required this.text,
    required this.time,
  });

  final String name;
  final String avatarText;
  final String text;
  final String time;
}
