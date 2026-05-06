import 'package:flutter/material.dart';

import 'search_result_type.dart';

class SearchResultItem {
  const SearchResultItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
    required this.color,
    required this.keywords,
    this.userId,
    this.username,
    this.roomId,
    this.roomLanguage,
    this.roomModeTitle,
    this.roomOnlineCount,
    this.vibeId,
    this.vibeAuthorId,
    this.vibeAuthorName,
  });

  final SearchResultType type;
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  /// Stable routing metadata. Today this is mock-driven; later backend search
  /// should return these fields directly so search never parses UI strings.
  final String? userId;
  final String? username;
  final String? roomId;
  final String? roomLanguage;
  final String? roomModeTitle;
  final int? roomOnlineCount;
  final String? vibeId;
  final String? vibeAuthorId;
  final String? vibeAuthorName;

  bool matches(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return false;

    return title.toLowerCase().contains(cleanQuery) ||
        subtitle.toLowerCase().contains(cleanQuery) ||
        tag.toLowerCase().contains(cleanQuery) ||
        (userId?.toLowerCase().contains(cleanQuery) ?? false) ||
        (username?.toLowerCase().contains(cleanQuery) ?? false) ||
        (roomId?.toLowerCase().contains(cleanQuery) ?? false) ||
        (vibeId?.toLowerCase().contains(cleanQuery) ?? false) ||
        (vibeAuthorId?.toLowerCase().contains(cleanQuery) ?? false) ||
        (vibeAuthorName?.toLowerCase().contains(cleanQuery) ?? false) ||
        keywords.any((keyword) => keyword.toLowerCase().contains(cleanQuery));
  }
}
