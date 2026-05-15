import 'package:flutter/material.dart';

enum VibesFeedTab {
  vibes('Vibes'),
  friends('Friends');

  const VibesFeedTab(this.label);
  final String label;
}

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
    this.avatarUrl,
    this.likedByMe = false,
    this.savedByMe = false,
    this.commentsEnabled = true,
    this.saves = 0,
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
  final String? avatarUrl;
  final bool likedByMe;
  final bool savedByMe;
  final bool commentsEnabled;
  final int saves;

  bool get hasMediaUrl => mediaUrl != null && mediaUrl!.trim().isNotEmpty;
  bool get hasAvatarUrl => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  VibeItem copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? saves,
    String? mediaUrl,
    String? avatarUrl,
    bool? likedByMe,
    bool? savedByMe,
    bool? commentsEnabled,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      likedByMe: likedByMe ?? this.likedByMe,
      savedByMe: savedByMe ?? this.savedByMe,
      commentsEnabled: commentsEnabled ?? this.commentsEnabled,
      saves: saves ?? this.saves,
    );
  }
}

class VibeComment {
  const VibeComment({
    required this.id,
    required this.name,
    required this.avatarText,
    required this.text,
    required this.time,
    this.avatarUrl,
    this.isPinned = false,
    this.canPin = false,
    this.canDelete = false,
  });

  final String id;
  final String name;
  final String avatarText;
  final String text;
  final String time;
  final String? avatarUrl;
  final bool isPinned;
  final bool canPin;
  final bool canDelete;

  bool get hasAvatarUrl => avatarUrl != null && avatarUrl!.trim().isNotEmpty;

  VibeComment copyWith({bool? isPinned}) {
    return VibeComment(
      id: id,
      name: name,
      avatarText: avatarText,
      text: text,
      time: time,
      avatarUrl: avatarUrl,
      isPinned: isPinned ?? this.isPinned,
      canPin: canPin,
      canDelete: canDelete,
    );
  }
}
