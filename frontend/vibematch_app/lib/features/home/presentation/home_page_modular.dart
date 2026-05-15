import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../../auth/models/current_user.dart';
import '../../create/presentation/create_page.dart';
import '../controllers/home_controller.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';
import 'sections/home_banner_section.dart';
import 'sections/home_filters_section.dart';
import 'sections/home_header_section.dart';
import 'sections/home_room_list_section.dart';
import 'sections/home_room_section_header.dart';
import 'widgets/home_backend_connected_strip.dart';
import 'widgets/home_language_sheet.dart';
import 'widgets/home_loading_strip.dart';
import 'widgets/home_locked_room_sheet.dart';
import 'widgets/home_network_error_card.dart';

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

  CurrentUser? get _activeCurrentUser {
    final activeUser = widget.currentUser ?? widget.user;
    return activeUser is CurrentUser ? activeUser : null;
  }

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
    final dynamic activeUser = widget.user ?? widget.currentUser;
    try {
      final primaryRole = activeUser?.primaryRole?.toString().toLowerCase();
      final roles = activeUser?.roles;
      if (primaryRole == 'founder_owner' || primaryRole == 'super_owner' || primaryRole == 'owner') return true;
      if (roles is Iterable) {
        return roles.any((role) {
          final normalized = role.toString().toLowerCase();
          return normalized == 'founder_owner' || normalized == 'owner' || normalized == 'super_owner' || normalized == 'banner_manager' || normalized == 'manage_home_banners' || normalized == 'permission_manage_home_banners';
        });
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: const Color(0xFF251538), content: Text(message)));
  }

  Future<void> _openMyRoomOrCreate() async {
    final existingRoom = _controller.myCreatedRoom;
    if (existingRoom != null) {
      _enterRoom(existingRoom);
      return;
    }

    final currentUser = _activeCurrentUser;
    if (currentUser == null) {
      _toast('Login session not ready. Refresh and try again.');
      return;
    }

    await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => CreatePage(currentUser: currentUser)));
    if (!mounted) return;
    await _controller.refreshAfterRoomCreation();
  }

  void _openRoom(HomeRoom room) {
    final mode = room.mode.toLowerCase();
    if (mode.contains('secret')) {
      _toast('No permission to enter this Secret Vibe room');
      return;
    }
    if (mode.contains('member')) {
      _toast('Members Only room. Membership approval required.');
      return;
    }
    if (mode.contains('lock')) {
      _openLockedRoomSheet(room);
      return;
    }
    _enterRoom(room);
  }

  void _enterRoom(HomeRoom room) {
    VmNavigator.openLiveRoom(context, roomName: room.name, roomId: room.id, language: room.language, modeTitle: room.mode, onlineCount: room.onlineCount, currentUser: _activeCurrentUser);
  }

  void _openLockedRoomSheet(HomeRoom room) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HomeLockedRoomSheet(room: room, onWrongPassword: () => _toast('Wrong password.'), onPasswordAccepted: () => _enterRoom(room)),
    );
  }

  void _openLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HomeLanguageSheet(
        languages: _controller.languages,
        selectedLanguage: _controller.selectedLanguage,
        onLanguageSelected: (language) {
          _controller.selectLanguage(language);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _seeAllRooms() {
    _controller.seeAllRooms();
    if (_controller.selectedCategory == 'Following') {
      _toast('Showing all rooms where followed users are active');
      return;
    }
    _toast('Showing all public open rooms');
  }

  void _handleBannerTap(HomeBanner banner) {
    switch (banner.target) {
      case 'event':
        VmNavigator.openEvents(context);
        return;
      case 'recharge':
        VmNavigator.openWallet(context);
        return;
      case 'promo':
        VmNavigator.openStore(context);
        return;
      default:
        VmNavigator.openEvents(context);
        return;
    }
  }

  void _handlePolicyBannerTap(HomeBanner banner) {
    if (banner.target == 'policy') {
      VmNavigator.openSettings(context);
      return;
    }
    _toast(banner.title);
  }

  @override
  Widget build(BuildContext context) {
    final visibleRooms = _controller.visibleRooms;
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _controller.refreshAll,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: HomeHeaderSection(myCreatedRoom: _controller.myCreatedRoom, onMyRoomTap: _openMyRoomOrCreate, onSearchTap: () => VmNavigator.openSearch(context), onNotificationsTap: () => VmNavigator.openNotifications(context))),
              if (_controller.bannerErrorMessage != null)
                SliverToBoxAdapter(child: HomeNetworkErrorCard(message: _controller.bannerErrorMessage!, onRetry: _controller.loadHomeChrome))
              else if (_controller.banners.isNotEmpty)
                SliverToBoxAdapter(child: HomeBannerSection(banners: _controller.banners, selectedIndex: _controller.selectedBannerIndex, canManageHomeBanners: _canManageHomeBanners, onBannerChanged: _controller.selectBanner, onBannerTap: _handleBannerTap, onManageTap: () => VmNavigator.openBannerManager(context))),
              SliverToBoxAdapter(child: HomeFiltersSection(categories: _controller.categories, selectedCategory: _controller.selectedCategory, selectedLanguage: _controller.selectedLanguage, onCategorySelected: _controller.selectCategory, onLanguageTap: _openLanguageSheet, onSeeAllTap: _seeAllRooms)),
              if (_controller.isLoadingRooms)
                const SliverToBoxAdapter(child: HomeLoadingStrip())
              else if (_controller.loadErrorMessage != null)
                SliverToBoxAdapter(child: HomeNetworkErrorCard(message: _controller.loadErrorMessage!, onRetry: _controller.retryLoadingRooms))
              else if (_controller.usingBackendRooms)
                const SliverToBoxAdapter(child: HomeBackendConnectedStrip()),
              SliverToBoxAdapter(child: HomeRoomSectionHeader(selectedCategory: _controller.selectedCategory, totalRooms: _controller.filteredRooms.length)),
              HomeRoomListSection(
                visibleRooms: visibleRooms,
                selectedCategory: _controller.selectedCategory,
                hasLoadError: _controller.loadErrorMessage != null,
                policyBanners: _controller.policyBanners,
                selectedPolicyBannerIndex: _controller.selectedPolicyBannerIndex,
                canManageBanners: _canManageHomeBanners,
                onRoomTap: _openRoom,
                onPolicyBannerChanged: _controller.selectPolicyBanner,
                onPolicyBannerTap: _handlePolicyBannerTap,
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
