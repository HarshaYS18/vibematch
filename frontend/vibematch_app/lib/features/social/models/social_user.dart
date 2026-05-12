import 'package:flutter/material.dart';

class SocialUser {
  const SocialUser({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarText,
    required this.colors,
    this.publicUserId,
    this.avatarUrl,
    this.lastSeenAt,
    this.isOnline = false,
    this.isFollowing = false,
    this.isFollower = false,
  });

  final String id;
  final int? publicUserId;
  final String displayName;
  final String username;
  final String avatarText;
  final String? avatarUrl;
  final List<Color> colors;
  final bool isOnline;
  final bool isFollowing;
  final bool isFollower;
  final DateTime? lastSeenAt;

  bool get isFriend => isFollowing && isFollower;

  String get mentionToken => username.trim().isEmpty ? displayName : username;

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    final publicId = _nullableInt(json['public_user_id']);
    final backendId = _nullableInt(json['id']);
    final username = _nullableText(json['username']);
    final displayName = _nullableText(json['display_name']) ?? username ?? 'Vibe User';
    final avatarTextSource = displayName.trim().isNotEmpty ? displayName.trim() : (username ?? 'V');
    return SocialUser(
      id: (publicId ?? backendId ?? displayName.hashCode).toString(),
      publicUserId: publicId,
      displayName: displayName,
      username: username ?? (publicId == null ? displayName.toLowerCase().replaceAll(' ', '_') : publicId.toString()),
      avatarText: avatarTextSource.characters.first.toUpperCase(),
      avatarUrl: _nullableText(json['avatar_url']),
      colors: gradientForSeed(publicId?.toString() ?? username ?? displayName),
      isOnline: json['is_online'] == true,
      isFollowing: json['is_following'] != false,
      isFollower: json['follows_me'] != false && json['is_followed_by'] != false,
      lastSeenAt: _date(json['last_seen_at']),
    );
  }

  static List<Color> gradientForSeed(String seed) {
    const palettes = <List<Color>>[
      [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
      [Color(0xFFE84C72), Color(0xFFC99A3B)],
      [Color(0xFFFFC857), Color(0xFF8C5CF6)],
      [Color(0xFF8C5CF6), Color(0xFF12C7B7)],
      [Color(0xFFC99A3B), Color(0xFFE84C72)],
      [Color(0xFFE84C72), Color(0xFF8C8198)],
    ];
    return palettes[seed.hashCode.abs() % palettes.length];
  }
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _nullableText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _date(dynamic value) {
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) return DateTime.tryParse(value);
  return null;
}
