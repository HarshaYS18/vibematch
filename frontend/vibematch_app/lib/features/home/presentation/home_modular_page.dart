import 'package:flutter/material.dart';

import '../../rooms/presentation/live_room_page.dart';
import '../controllers/home_access_controller.dart';
import '../controllers/home_filter_controller.dart';
import '../controllers/trending_rooms_controller.dart';
import '../data/home_mock_data.dart';
import '../models/home_room_model.dart';
import 'sheets/home_language_sheet_modular.dart';
import 'sheets/home_search_sheet_modular.dart';
import 'widgets/home_empty_state_modular.dart';
import 'widgets/home_filter_bar.dart';
import 'widgets/home_highlights_carousel.dart';
import 'widgets/home_room_card_modular.dart';
import 'widgets/home_room_section_header.dart';
import 'widgets/home_top_search_action.dart';

class HomeModularPage extends StatefulWidget {
  const HomeModularPage({
    super.key,
    this.user,
    this.currentUser,
  });

  final Object? user;
  final Object? currentUser;

  @override
  State<HomeModularPage> createState() => _HomeModularPageState();
}

class _HomeModularPageState extends State<HomeModularPage> {
  late final ScrollController _scrollController;
  late final HomeAccessController _accessController;
  late final HomeFilterController _filterController;
  late final TrendingRoomsController _roomsController;

  int _selectedHighlightIndex = 0;

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()..addListener(_handleScroll);
    _accessController = HomeAccessController(
      activeUser: widget.user ?? widget.currentUser,
    );
    _filterController = HomeFilterController(
      languages: HomeMockData.languages,
      initialCategory: 'Trending',
      initialLanguage: 'All',
    )..addListener(_handleFiltersChanged);
    _roomsController = TrendingRoomsController(
      allRooms: HomeMockData.rooms,
    )..applyFilters(
        category: _filterController.selectedCategory,
        language: _filterController.selectedLanguage,
      );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _filterController.removeListener(_handleFiltersChanged);
    _filterController.dispose();
    _roomsController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    _roomsController.loadMoreIfNeeded(
      pixels: _scrollController.position.pixels,
      maxScrollExtent: _scrollController.position.maxScrollExtent,
    );
  }

  void _handleFiltersChanged() {
    _roomsController.applyFilters(
      category: _filterController.selectedCategory,
      language: _filterController.selectedLanguage,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF251538),
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  void _openSearchSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeSearchSheetModular(
        onMockSearch: (query) => _toast('Search opened for "$query"'),
      ),
    );
  }

  void _openLanguageSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HomeLanguageSheetModular(
        languages: _filterController.languages,
        selectedLanguage: _filterController.selectedLanguage,
        onLanguageSelected: _filterController.selectLanguage,
      ),
    );
  }

  void _openHighlightManage() {
    _toast('Home highlight management opened for official account');
  }

  void _openRoom(HomeRoomModel room) {
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

  void _enterRoom(HomeRoomModel room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveRoomPage(
          roomName: room.name,
          roomId: room.id,
          language: room.language,
          modeTitle: room.mode,
          onlineCount: room.onlineCount,
        ),
      ),
    );
  }

  void _openLockedRoomSheet(HomeRoomModel room) {
    final passwordController = TextEditingController();
    bool passwordVisible = false;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                18,
                10,
                18,
                MediaQuery.paddingOf(context).bottom + 18,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1D8E7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC99A3B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Color(0xFFC99A3B),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Locked Room',
                    style: TextStyle(
                      color: Color(0xFF251538),
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    room.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: passwordController,
                    obscureText: !passwordVisible,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      color: Color(0xFF251538),
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter password',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9B8CA5),
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFC99A3B),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setSheetState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: const Color(0xFF7B6A86),
                        ),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFFAF7F1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: Color(0xFFEDE3D7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: Color(0xFFC99A3B),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mock password: 1234',
                      style: TextStyle(
                        color: Color(0xFF9B8CA5),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF251538),
                          ),
                          onPressed: () {
                            final password = passwordController.text.trim();
                            if (password != '1234') {
                              _toast('Wrong password. Use 1234 for mock room.');
                              return;
                            }
                            Navigator.pop(context);
                            _enterRoom(room);
                          },
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('Enter'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(passwordController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_filterController, _roomsController]),
      builder: (context, _) {
        final visibleRooms = _roomsController.visibleRooms;
        final filteredRooms = _roomsController.filteredRooms;

        return Scaffold(
          backgroundColor: const Color(0xFFFAF7F1),
          body: SafeArea(
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: HomeTopSearchAction(onSearchTap: _openSearchSheet),
                ),
                SliverToBoxAdapter(
                  child: HomeHighlightsCarousel(
                    highlights: HomeMockData.highlights,
                    selectedIndex: _selectedHighlightIndex,
                    canManageHighlights: _accessController.canManageHighlights,
                    onPageChanged: (index) {
                      setState(() => _selectedHighlightIndex = index);
                    },
                    onHighlightTap: (item) => _toast('${item.title} opened'),
                    onManageTap: _openHighlightManage,
                  ),
                ),
                SliverToBoxAdapter(
                  child: HomeFilterBar(
                    categories: HomeMockData.categories,
                    selectedCategory: _filterController.selectedCategory,
                    selectedLanguage: _filterController.selectedLanguage,
                    onCategorySelected: _filterController.selectCategory,
                    onLanguageTap: _openLanguageSheet,
                    onSeeAllTap: () {
                      _roomsController.showAll();
                      _toast(
                        _filterController.selectedCategory == 'Following'
                            ? 'Showing all rooms where followed users are active'
                            : 'Showing all public open rooms',
                      );
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: HomeRoomSectionHeader(
                    selectedCategory: _filterController.selectedCategory,
                    totalCount: filteredRooms.length,
                  ),
                ),
                if (visibleRooms.isEmpty)
                  SliverToBoxAdapter(
                    child: HomeEmptyStateModular(
                      selectedCategory: _filterController.selectedCategory,
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: visibleRooms.length,
                    itemBuilder: (context, index) {
                      final room = visibleRooms[index];
                      return HomeRoomCardModular(
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
        );
      },
    );
  }
}
