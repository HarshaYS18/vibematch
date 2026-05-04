enum ManagedBannerSection {
  eventBanner('Event Banner'),
  displayBanner('Display Banner'),
  policyBanner('Policy Banner');

  const ManagedBannerSection(this.label);

  final String label;
}

enum ManagedBannerTarget {
  event('Event'),
  promo('Promo'),
  recharge('Recharge'),
  policy('Rules / Policies'),
  externalLink('External Link Later');

  const ManagedBannerTarget(this.label);

  final String label;
}

class ManagedBannerDraft {
  const ManagedBannerDraft({
    required this.id,
    required this.section,
    required this.title,
    required this.target,
    required this.imageLabel,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.sortOrder,
  });

  final String id;
  final ManagedBannerSection section;
  final String title;
  final ManagedBannerTarget target;
  final String imageLabel;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int sortOrder;
}
