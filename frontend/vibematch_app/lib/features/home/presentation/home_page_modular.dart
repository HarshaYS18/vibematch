import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../controllers/home_controller.dart';
import '../controllers/home_navigation_controller.dart';
import 'sections/home_banner_section.dart';
import 'sections/home_filters_section.dart';
import 'sections/home_header_section.dart';
import 'sections/home_room_list_section.dart';
import 'sections/home_room_section_header.dart';
import 'widgets/home_loading_strip.dart';
import 'widgets/home_network_error_card.dart';
import 'widgets/home_official_banner_manage_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({
    super.key,
    this.user,
    this.currentUser,
  });

  final Object? user;
  final Object? currentUser;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(homeControllerProvider.notifier).refreshAll();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    ref.read(homeControllerProvider.notifier).onScrollNearBottom(_scrollController);
  }

  bool get _canManageHomeBanners {
    return HomeNavigationController.canManageHomeBanners(widget.user, widget.currentUser);
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);
    final visibleRooms = home.visibleRooms;
    final activeCurrentUser = HomeNavigationController.activeCurrentUser(widget.user, widget.currentUser);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refreshAll,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: HomeHeaderSection(
                  myCreatedRoom: home.myCreatedRoom,
                  onMyRoomTap: () => HomeNavigationController.openMyRoomOrCreate(
                    context: context,
                    controller: controller,
                    currentUser: activeCurrentUser,
                  ),
                  onQuickMatchTap: () => unawaited(
                    HomeNavigationController.quickMatch(
                      context: context,
                      controller: controller,
                      currentUser: activeCurrentUser,
                    ),
                  ),
                  onSearchTap: () => VmNavigator.openSearch(context),
                  onNotificationsTap: () => VmNavigator.openNotifications(context),
                ),
              ),
              if (_canManageHomeBanners)
                SliverToBoxAdapter(
                  child: HomeOfficialBannerManageCard(
                    onTap: () => VmNavigator.openBannerManager(context),
                  ),
                ),
              if (home.bannerErrorMessage != null)
                SliverToBoxAdapter(
                  child: HomeNetworkErrorCard(
                    message: home.bannerErrorMessage!,
                    onRetry: controller.loadHomeChrome,
                  ),
                )
              else if (home.banners.isNotEmpty)
                SliverToBoxAdapter(
                  child: HomeBannerSection(
                    banners: home.banners,
                    selectedIndex: home.selectedBannerIndex,
                    canManageHomeBanners: _canManageHomeBanners,
                    onBannerChanged: controller.selectBanner,
                    onBannerTap: (banner) => HomeNavigationController.handleBannerTap(context, banner),
                    onManageTap: () => VmNavigator.openBannerManager(context),
                  ),
                ),
              SliverToBoxAdapter(
                child: HomeFiltersSection(
                  categories: HomeController.categories,
                  selectedCategory: home.selectedCategory,
                  selectedLanguage: home.selectedLanguage,
                  onCategorySelected: controller.selectCategory,
                  onLanguageTap: () => HomeNavigationController.openLanguageSheet(context: context, controller: controller),
                ),
              ),
              if (home.isLoadingRooms)
                const SliverToBoxAdapter(child: HomeLoadingStrip())
              else if (home.loadErrorMessage != null)
                SliverToBoxAdapter(
                  child: HomeNetworkErrorCard(
                    message: home.loadErrorMessage!,
                    onRetry: controller.retryLoadingRooms,
                  ),
                ),
              SliverToBoxAdapter(
                child: HomeRoomSectionHeader(
                  selectedCategory: home.selectedCategory,
                  totalRooms: home.filteredRooms.length,
                ),
              ),
              HomeRoomListSection(
                visibleRooms: visibleRooms,
                selectedCategory: home.selectedCategory,
                hasLoadError: home.loadErrorMessage != null,
                policyBanners: home.policyBanners,
                selectedPolicyBannerIndex: home.selectedPolicyBannerIndex,
                canManageBanners: _canManageHomeBanners,
                onRoomTap: (room) => HomeNavigationController.openRoom(
                  context: context,
                  room: room,
                  currentUser: activeCurrentUser,
                ),
                onPolicyBannerChanged: controller.selectPolicyBanner,
                onPolicyBannerTap: (banner) => HomeNavigationController.handlePolicyBannerTap(context, banner),
                onManageBannersTap: () => VmNavigator.openBannerManager(context),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}
