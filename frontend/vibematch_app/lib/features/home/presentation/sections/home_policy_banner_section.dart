import 'package:flutter/material.dart';

import '../../models/home_banner.dart';
import 'home_banner_section.dart';

class HomePolicyBannerSection extends StatelessWidget {
  const HomePolicyBannerSection({
    super.key,
    required this.banners,
    required this.selectedIndex,
    required this.canManageBanners,
    required this.onBannerChanged,
    required this.onBannerTap,
    required this.onManageTap,
  });

  final List<HomeBanner> banners;
  final int selectedIndex;
  final bool canManageBanners;
  final ValueChanged<int> onBannerChanged;
  final ValueChanged<HomeBanner> onBannerTap;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: Row(
            children: [
              Icon(Icons.policy_rounded, color: Color(0xFF4A2A63), size: 17),
              SizedBox(width: 7),
              Text(
                'Rules & Policies',
                style: TextStyle(
                  color: Color(0xFF251538),
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        HomeBannerSection(
          banners: banners,
          selectedIndex: selectedIndex,
          canManageHomeBanners: canManageBanners,
          onBannerChanged: onBannerChanged,
          onBannerTap: onBannerTap,
          onManageTap: onManageTap,
        ),
      ],
    );
  }
}
