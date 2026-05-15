import 'package:flutter/material.dart';

import '../../models/home_banner.dart';

class HomeBannerDto {
  const HomeBannerDto({
    required this.id,
    required this.title,
    required this.placement,
    required this.target,
    required this.sortOrder,
    required this.isActive,
    this.imageUrl,
    this.targetUrl,
    this.description,
  });

  final String id;
  final String title;
  final String placement;
  final String target;
  final String? imageUrl;
  final String? targetUrl;
  final String? description;
  final int sortOrder;
  final bool isActive;

  factory HomeBannerDto.fromJson(Map<String, dynamic> json) {
    final placement = json['placement']?.toString() ?? 'event';
    return HomeBannerDto(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Banner',
      placement: placement,
      target: json['target']?.toString() ?? (placement == 'policy_rules' ? 'policy' : 'event'),
      imageUrl: _cleanString(json['image_url'] ?? json['imageUrl']),
      targetUrl: _cleanString(json['target_url'] ?? json['targetUrl']),
      description: _cleanString(json['description']),
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 1,
      isActive: json['is_active'] != false,
    );
  }

  HomeBanner toDomain() {
    return HomeBanner(
      id: id,
      title: title,
      imageUrl: imageUrl,
      placement: placement,
      target: target,
      targetUrl: targetUrl,
      description: description,
      sortOrder: sortOrder,
      isActive: isActive,
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
