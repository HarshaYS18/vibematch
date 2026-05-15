import 'package:flutter/material.dart';

import '../../models/home_banner.dart';
import '../../models/home_room.dart';
import '../widgets/home_room_card.dart';
import 'home_empty_state.dart';
import 'home_policy_banner_section.dart';

class HomeRoomListSection extends StatelessWidget {
  const HomeRoomListSection({
    super.key,
    required this.visibleRooms,
    required this.selectedCategory,
    required this.hasLoadError,
    required this.policyBanners,
    required this.selectedPolicyBannerIndex,
    required this.canManageBanners,
    required this.onRoomTap,
    required this.onPolicyBannerChanged,
    required this.onPolicyBannerTap,
    required this.onManageBannersTap,
  });

  final List<HomeRoom> visibleRooms;
  final String selectedCategory;
  final bool hasLoadError;
  final List<HomeBanner> policyBanners;
  final int selectedPolicyBannerIndex;
  final bool canManageBanners;
  final ValueChanged<HomeRoom> onRoomTap;
  final ValueChanged<int> onPolicyBannerChanged;
  final ValueChanged<HomeBanner> onPolicyBannerTap;
  final VoidCallback onManageBannersTap;

  bool get _shouldShowPolicyBanner => policyBanners.isNotEmpty && visibleRooms.length >= 6;

  @override
  Widget build(BuildContext context) {
    if (visibleRooms.isEmpty && !hasLoadError) {
      return SliverToBoxAdapter(child: HomeEmptyState(selectedCategory: selectedCategory));
    }

    return SliverList.builder(
      itemCount: visibleRooms.length + (_shouldShowPolicyBanner ? 1 : 0),
      itemBuilder: (context, index) {
        if (_shouldShowPolicyBanner && index == 6) {
          return HomePolicyBannerSection(
            banners: policyBanners,
            selectedIndex: selectedPolicyBannerIndex,
            canManageBanners: canManageBanners,
            onBannerChanged: onPolicyBannerChanged,
            onBannerTap: onPolicyBannerTap,
            onManageTap: onManageBannersTap,
          );
        }

        final roomIndex = _shouldShowPolicyBanner && index > 6 ? index - 1 : index;
        final room = visibleRooms[roomIndex];
        return HomeRoomCard(room: room, rank: roomIndex + 1, onTap: () => onRoomTap(room));
      },
    );
  }
}
