import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../controllers/home_controller.dart';
import '../controllers/home_navigation_controller.dart';
import 'sections/home_banner_section.dart';
import 'sections/home_filters_section.dart';
import 'sections/home_header_section.dart';
import 'sections/home_room_list_section.dart';
import 'sections/home_room_section_header.dart';
import 'widgets/home_backend_connected_strip.dart';
import 'widgets/home_loading_strip.dart';
import 'widgets/home_network_error_card.dart';
import 'widgets/home_official_banner_manage_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.user,
    this.currentUser,
  });

  final Object? user;
  final Object? currentUser;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final HomeController _controller = HomeController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refreshAll();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _controller.removeListener(_handleControllerChanged);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleScroll() {
    _controller.onScrollNearBottom(_scrollController);
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  bool get _canManageHomeBanners {
    return HomeNavigationController.canManageHomeBanners(widget.user, widget.currentUser);
  }

  @override
  Widget build(BuildContext context) {
    final visibleRooms = _controller.visibleRooms;
    final activeCurrentUser = HomeNavigationController.activeCurrentUser(widget.user, widget.currentUser);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _controller.refreshAll,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: HomeHeaderSection(
                  myCreatedRoom: _controller.myCreatedRoom,
                  onMyRoomTap: () => HomeNavigationController.openMyRoomOrCreate(
                    context: context,
                    controller: _controller,
                    currentUser: activeCurrentUser,
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
              if (_controller.bannerErrorMessage != null)
                SliverToBoxAdapter(
                  child: HomeNetworkErrorCard(
                    message: _controller.bannerErrorMessage!,
                    onRetry: _controller.loadHomeChrome,
                  ),
                )
              else if (_controller.banners.isNotEmpty)
                SliverToBoxAdapter(
                  child: HomeBannerSection(
                    banners: _controller.banners,
                    selectedIndex: _controller.selectedBannerIndex,
                    canManageHomeBanners: _canManageHomeBanners,
                    onBannerChanged: _controller.selectBanner,
                    onBannerTap: (banner) => HomeNavigationController.handleBannerTap(context, banner),
                    onManageTap: () => VmNavigator.openBannerManager(context),
                  ),
                ),
              SliverToBoxAdapter(
                child: HomeFiltersSection(
                  categories: _controller.categories,
                  selectedCategory: _controller.selectedCategory,
                  selectedLanguage: _controller.selectedLanguage,
                  onCategorySelected: _controller.selectCategory,
                  onLanguageTap: () => HomeNavigationController.openLanguageSheet(context: context, controller: _controller),
                ),
              ),
              if (_controller.isLoadingRooms)
                const SliverToBoxAdapter(child: HomeLoadingStrip())
              else if (_controller.loadErrorMessage != null)
                SliverToBoxAdapter(
                  child: HomeNetworkErrorCard(
                    message: _controller.loadErrorMessage!,
                    onRetry: _controller.retryLoadingRooms,
                  ),
                )
              else if (_controller.usingBackendRooms)
                const SliverToBoxAdapter(child: HomeBackendConnectedStrip()),
              SliverToBoxAdapter(
                child: HomeRoomSectionHeader(
                  selectedCategory: _controller.selectedCategory,
                  totalRooms: _controller.filteredRooms.length,
                ),
              ),
              HomeRoomListSection(
                visibleRooms: visibleRooms,
                selectedCategory: _controller.selectedCategory,
                hasLoadError: _controller.loadErrorMessage != null,
                policyBanners: _controller.policyBanners,
                selectedPolicyBannerIndex: _controller.selectedPolicyBannerIndex,
                canManageBanners: _canManageHomeBanners,
                onRoomTap: (room) => HomeNavigationController.openRoom(
                  context: context,
                  room: room,
                  currentUser: activeCurrentUser,
                ),
                onPolicyBannerChanged: _controller.selectPolicyBanner,
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
