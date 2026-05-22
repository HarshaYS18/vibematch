import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../controllers/home_controller.dart';
import '../controllers/home_navigation_controller.dart';
import 'sections/home_banner_section.dart';
import 'sections/home_filters_section.dart';
import 'sections/home_header_section.dart';
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
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.refreshAll();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  bool get _canManageHomeBanners {
    return HomeNavigationController.canManageHomeBanners(widget.user, widget.currentUser);
  }

  @override
  Widget build(BuildContext context) {
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: _PinnedRoomsComingSoonState(
                  selectedTab: _controller.selectedCategory,
                  canManageRooms: _canManageHomeBanners,
                  onManageTap: () => VmNavigator.openControlCenter(context),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedRoomsComingSoonState extends StatelessWidget {
  const _PinnedRoomsComingSoonState({required this.selectedTab, required this.canManageRooms, required this.onManageTap});

  final String selectedTab;
  final bool canManageRooms;
  final VoidCallback onManageTap;

  @override
  Widget build(BuildContext context) {
    final isFollowing = selectedTab == 'Following';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF251538), Color(0xFF8C5CF6)]),
              boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.14), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: Icon(isFollowing ? Icons.group_rounded : Icons.push_pin_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            isFollowing ? 'Following rooms will appear here' : 'Pinned rooms will appear here',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF251538), fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.2),
          ),
          const SizedBox(height: 6),
          Text(
            isFollowing ? 'Rooms from followed users stay separate from public trending.' : 'Owner Control Center can pin rooms for the Home page.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12, height: 1.25, fontWeight: FontWeight.w600),
          ),
          if (canManageRooms) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onManageTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(color: const Color(0xFF12C7B7), borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: const Color(0xFF12C7B7).withValues(alpha: 0.24), blurRadius: 12, offset: const Offset(0, 6))]),
                child: const Text('Manage pinned rooms', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
