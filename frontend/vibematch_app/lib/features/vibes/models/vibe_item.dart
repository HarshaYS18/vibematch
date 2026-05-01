import 'package:flutter/material.dart';

import 'vibe_media_type.dart';

class VibeItem {
  const VibeItem({
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
  });

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

  VibeItem copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? views,
  }) {
    return VibeItem(
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
      views: views ?? this.views,
      isFollowing: isFollowing,
      usesMentionAll: usesMentionAll,
      mentions: mentions,
      colors: colors,
    );
  }
}
