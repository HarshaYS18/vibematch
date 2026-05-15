enum ManagedBannerSection {
  eventBanner('Event Banner', 'event', 16 / 9, 1600, 900),
  policyBanner('Policy Banner', 'policy_rules', 16 / 9, 1600, 900);

  const ManagedBannerSection(this.label, this.placement, this.aspectRatio, this.outputWidth, this.outputHeight);

  final String label;
  final String placement;
  final double aspectRatio;
  final int outputWidth;
  final int outputHeight;
}

enum ManagedBannerTarget {
  event('Event', 'event'),
  promo('Promo', 'promo'),
  recharge('Recharge', 'recharge'),
  policy('Rules / Policies', 'policy'),
  externalLink('External Link Later', 'external');

  const ManagedBannerTarget(this.label, this.backendValue);

  final String label;
  final String backendValue;

  static ManagedBannerTarget fromBackend(String value) {
    for (final target in values) {
      if (target.backendValue == value) return target;
    }
    return event;
  }
}

class ManagedBanner {
  const ManagedBanner({
    required this.id,
    required this.section,
    required this.title,
    required this.target,
    required this.imageUrl,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final ManagedBannerSection section;
  final String title;
  final ManagedBannerTarget target;
  final String imageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final int sortOrder;

  factory ManagedBanner.fromJson(Map<String, dynamic> json) {
    final placement = json['placement']?.toString() ?? ManagedBannerSection.eventBanner.placement;
    return ManagedBanner(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      section: ManagedBannerSection.values.firstWhere(
        (section) => section.placement == placement,
        orElse: () => ManagedBannerSection.eventBanner,
      ),
      title: json['title']?.toString() ?? 'Banner',
      target: ManagedBannerTarget.fromBackend(json['target']?.toString() ?? 'event'),
      imageUrl: json['image_url']?.toString() ?? '',
      startDate: DateTime.tryParse(json['starts_at']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['ends_at']?.toString() ?? ''),
      isActive: json['is_active'] != false,
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 1,
    );
  }
}
