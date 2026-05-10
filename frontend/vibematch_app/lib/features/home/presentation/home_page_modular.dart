import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../../auth/models/current_user.dart';
import '../../create/presentation/create_page.dart';
import '../controllers/home_controller.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';
import 'sections/home_banner_section.dart';
import 'sections/home_empty_state.dart';
import 'sections/home_filters_section.dart';
import 'sections/home_header_section.dart';
import 'sections/home_policy_banner_section.dart';
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
      if (primaryRole == 'founder_owner' || primaryRole == 'super_owner') return true;
      if (roles is Iterable) {
        return roles.any((role) {
          final normalized = role.toString().toLowerCase();
          return normalized == 'founder_owner' || normalized == 'super_owner' || normalized == 'banner_manager' || normalized == 'manage_home_banners' || normalized == 'permission_manage_home_banners';
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
      builder: (_) => HomeLanguageSheet(languages: _controller.languages, selectedLanguage: _controller.selectedLanguage, onLanguageSelected: (language) { _controller.selectLanguage(language); Navigator.pop(context); }),
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
    VmNavigator.openEvents(context);
  }

  void _handlePolicyBannerTap(HomeBanner banner) {
    _toast('${banner.title} page will connect next.');
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
              SliverToBoxAdapter(child: HomeHeaderSection(myCreatedRoom: null, onMyRoomTap: _openMyRoomOrCreate, onSearchTap: () => VmNavigator.openSearch(context), onNotificationsTap: () => VmNavigator.openNotifications(context))),
              SliverToBoxAdapter(child: HomeBannerSection(banners: _controller.banners, selectedIndex: _controller.selectedBannerIndex, canManageHomeBanners: _canManageHomeBanners, onBannerChanged: _controller.selectBanner, onBannerTap: _handleBannerTap, onManageTap: () => VmNavigator.openBannerManager(context))),
              SliverToBoxAdapter(child: HomeFiltersSection(categories: _controller.categories, selectedCategory: _controller.selectedCategory, selectedLanguage: _controller.selectedLanguage, onCategorySelected: _controller.selectCategory, onLanguageTap: _openLanguageSheet, onSeeAllTap: _seeAllRooms)),
              if (_controller.isLoadingRooms)
                const SliverToBoxAdapter(child: _HomeLoadingStrip())
              else if (_controller.loadErrorMessage != null)
                SliverToBoxAdapter(child: _HomeNetworkErrorCard(message: _controller.loadErrorMessage!, onRetry: _controller.retryLoadingRooms))
              else if (_controller.usingBackendRooms)
                const SliverToBoxAdapter(child: _HomeBackendConnectedStrip()),
              SliverToBoxAdapter(child: HomeRoomSectionHeader(selectedCategory: _controller.selectedCategory, totalRooms: _controller.filteredRooms.length)),
              if (visibleRooms.isEmpty && _controller.loadErrorMessage == null)
                SliverToBoxAdapter(child: HomeEmptyState(selectedCategory: _controller.selectedCategory))
              else
                SliverList.builder(
                  itemCount: visibleRooms.length + (visibleRooms.length >= 6 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (visibleRooms.length >= 6 && index == 6) {
                      return HomePolicyBannerSection(banners: _controller.policyBanners, selectedIndex: _controller.selectedPolicyBannerIndex, canManageBanners: _canManageHomeBanners, onBannerChanged: _controller.selectPolicyBanner, onBannerTap: _handlePolicyBannerTap, onManageTap: () => VmNavigator.openBannerManager(context));
                    }
                    final roomIndex = index > 6 ? index - 1 : index;
                    final room = visibleRooms[roomIndex];
                    return HomeRoomCard(room: room, rank: roomIndex + 1, onTap: () => _openRoom(room));
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
    return const Padding(padding: EdgeInsets.fromLTRB(18, 0, 18, 12), child: LinearProgressIndicator(minHeight: 3, color: Color(0xFF12C7B7), backgroundColor: Color(0xFFECE2D8)));
  }
}

class _HomeNetworkErrorCard extends StatelessWidget {
  const _HomeNetworkErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE8C77C)), boxShadow: [BoxShadow(color: const Color(0xFF251538).withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8))]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFFFF7E8), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 23)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Network error', style: TextStyle(color: Color(0xFF251538), fontSize: 15, fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(message, style: const TextStyle(color: Color(0xFF7B6A86), fontSize: 12.2, fontWeight: FontWeight.w700, height: 1.25)),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: onRetry, style: FilledButton.styleFrom(backgroundColor: const Color(0xFF251538), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))), icon: const Icon(Icons.refresh_rounded, size: 17), label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w900)))),
            ]),
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
      decoration: BoxDecoration(color: const Color(0xFFE8FAF7), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFB7EFE6))),
      child: const Row(children: [Icon(Icons.cloud_done_rounded, color: Color(0xFF12C7B7), size: 18), SizedBox(width: 8), Expanded(child: Text('Live room list loaded from backend.', style: TextStyle(color: Color(0xFF4A2A63), fontSize: 11.5, fontWeight: FontWeight.w800)))]),
    );
  }
}
