import 'package:flutter/material.dart';

class HomeBanner {
  final String id;
  final String title;
  final String? imageUrl;
  final String placement;
  final String target;
  final String? targetUrl;
  final String? description;
  final int sortOrder;
  final bool isActive;
  final IconData fallbackIcon;
  final List<Color> fallbackGradient;

  const HomeBanner({
    required this.id,
    required this.title,
    this.imageUrl,
    this.placement = 'event',
    this.target = 'event',
    this.targetUrl,
    this.description,
    this.sortOrder = 1,
    this.isActive = true,
    required this.fallbackIcon,
    required this.fallbackGradient,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    final placement = json['placement']?.toString() ?? 'event';
    final target = json['target']?.toString() ?? (placement == 'policy_rules' ? 'policy' : 'event');
    return HomeBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Banner',
      imageUrl: _cleanString(json['image_url'] ?? json['imageUrl']),
      placement: placement,
      target: target,
      targetUrl: _cleanString(json['target_url'] ?? json['targetUrl']),
      description: _cleanString(json['description']),
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 1,
      isActive: json['is_active'] != false,
      fallbackIcon: placement == 'policy_rules' ? Icons.rule_rounded : Icons.celebration_rounded,
      fallbackGradient: placement == 'policy_rules'
          ? const [Color(0xFF251538), Color(0xFF4A2A63)]
          : const [Color(0xFFE84C72), Color(0xFF8C5CF6)],
    );
  }

  static String? _cleanString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}
