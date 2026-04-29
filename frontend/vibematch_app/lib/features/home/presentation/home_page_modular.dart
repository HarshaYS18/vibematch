import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../controllers/home_controller.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';
import 'sections/home_banner_section.dart';
import 'sections/home_empty_state.dart';
import 'sections/home_filters_section.dart';
import 'sections/home_header_section.dart';
import 'sections/home_room_section_header.dart';
import 'widgets/home_language_sheet.dart';
import 'widgets/home_locked_room_sheet.dart';
import 'widgets/home_room_card.dart';

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
      if (mounted) _controller.loadTrendingRooms(silent: true);
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

      if (primaryRole == 'founder_owner' || primaryRole == 'super_owner' || primaryRole == 'owner') {
        return true;
      }

      if (roles is Iterable) {
        return roles.any((role) {
          final normalized = role.toString().toLowerCase();
          return normalized == 'founder_owner' || normalized == 'super_owner' || normalized == 'owner';
        });
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF251538),
        content: Text(message),
      ),
    );
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
    VmNavigator.openLiveRoom(
      context,
      roomName: room.name,
      roomId: room.id,
      language: room.language,
      modeTitle: room.mode,
      onlineCount: room.onlineCount,
    );
  }

  void _openLockedRoomSheet(HomeRoom room) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HomeLockedRoomSheet(
        room: room,
        onWrongPassword: () => _toast('Wrong password. Use 1234 for mock room.'),
        onPasswordAccepted: () => _enterRoom(room),
      ),
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
    switch (banner.action) {
      case HomeBannerAction.openEvents:
        VmNavigator.openEvents(context);
        return;
      case HomeBannerAction.openTrendingRooms:
        _controller.selectCategory('Trending');
        _toast('Trending rooms selected');
        return;
      case HomeBannerAction.openVibeSyncRooms:
        _controller.selectCategory('Music');
        _toast('Vibe Sync rooms highlighted');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRooms = _controller.visibleRooms;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _controller.loadTrendingRooms(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: HomeHeaderSection(
                  onSearchTap: () => VmNavigator.openSearch(context),
                  onNotificationsTap: () => VmNavigator.openNotifications(context),
                ),
              ),
              SliverToBoxAdapter(
                child: HomeBannerSection(
                  banners: _controller.banners,
                  selectedIndex: _controller.selectedBannerIndex,
                  canManageHomeBanners: _canManageHomeBanners,
                  onBannerChanged: _controller.selectBanner,
                  onBannerTap: _handleBannerTap,
                  onManageTap: () => _toast('Banner management opened for official account'),
                ),
              ),
              SliverToBoxAdapter(
                child: HomeFiltersSection(
                  categories: _controller.categories,
                  selectedCategory: _controller.selectedCategory,
                  selectedLanguage: _controller.selectedLanguage,
                  onCategorySelected: _controller.selectCategory,
                  onLanguageTap: _openLanguageSheet,
                  onSeeAllTap: _seeAllRooms,
                ),
              ),
              if (_controller.isLoadingRooms)
                const SliverToBoxAdapter(child: _HomeLoadingStrip())
              else if (_controller.loadErrorMessage != null)
                SliverToBoxAdapter(
                  child: _HomeBackendFallbackStrip(message: _controller.loadErrorMessage!),
                )
              else if (_controller.usingBackendRooms)
                const SliverToBoxAdapter(child: _HomeBackendConnectedStrip()),
              SliverToBoxAdapter(
                child: HomeRoomSectionHeader(
                  selectedCategory: _controller.selectedCategory,
                  totalRooms: _controller.filteredRooms.length,
                ),
              ),
              if (visibleRooms.isEmpty)
                SliverToBoxAdapter(
                  child: HomeEmptyState(selectedCategory: _controller.selectedCategory),
                )
              else
                SliverList.builder(
                  itemCount: visibleRooms.length,
                  itemBuilder: (context, index) {
                    final room = visibleRooms[index];
                    return HomeRoomCard(
                      room: room,
                      rank: index + 1,
                      onTap: () => _openRoom(room),
                    );
                  },
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeLoadingStrip extends StatelessWidget {
  const _HomeLoadingStrip();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: LinearProgressIndicator(
        minHeight: 3,
        color: Color(0xFF12C7B7),
        backgroundColor: Color(0xFFECE2D8),
      ),
    );
  }
}

class _HomeBackendFallbackStrip extends StatelessWidget {
  const _HomeBackendFallbackStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8C77C)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: Color(0xFFC99A3B), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF4A2A63),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBackendConnectedStrip extends StatelessWidget {
  const _HomeBackendConnectedStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8FAF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFB7EFE6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_done_rounded, color: Color(0xFF12C7B7), size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Live room list loaded from backend.',
              style: TextStyle(
                color: Color(0xFF4A2A63),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
