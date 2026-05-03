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
  });

  final SearchResultType type;
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;
  final Color color;
  final List<String> keywords;

  bool matches(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return false;

    return title.toLowerCase().contains(cleanQuery) ||
        subtitle.toLowerCase().contains(cleanQuery) ||
        tag.toLowerCase().contains(cleanQuery) ||
        keywords.any((keyword) => keyword.toLowerCase().contains(cleanQuery));
  }
}
