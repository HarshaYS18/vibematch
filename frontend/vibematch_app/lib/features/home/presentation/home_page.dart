import 'package:flutter/material.dart';

import '../../rooms/presentation/live_room_page.dart';

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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _lockPasswordController =
      TextEditingController();

  int _selectedBannerIndex = 0;
  int _visibleRoomCount = 6;
  String _selectedCategory = 'Trending';
  String _selectedLanguage = 'All';

  final List<String> _categories = const [
    'Trending',
    'Following',
    'Music',
    'Gaming',
    'Chat',
    'PK',
  ];

  final List<String> _languages = const [
    'All',
    'Telugu',
    'Hindi',
    'English',
    'Tamil',
    'Malayalam',
    'Kannada',
    'Bengali',
    'Marathi',
    'Punjabi',
    'Gujarati',
    'Odia',
    'Urdu',
    'Arabic',
    'Spanish',
    'French',
    'Other',
  ];

  final List<_HomeBanner> _banners = const [
    _HomeBanner(
      title: 'Tonight’s Premium Rooms',
      subtitle: 'Join trending voice rooms with live seats and gifts.',
      icon: Icons.graphic_eq_rounded,
      gradient: [
        Color(0xFF12C7B7),
        Color(0xFF8C5CF6),
        Color(0xFFE84C72),
      ],
    ),
    _HomeBanner(
      title: 'Vibe Sync Rooms',
      subtitle: 'Music-style live rooms with animated mood and energy.',
      icon: Icons.waves_rounded,
      gradient: [
        Color(0xFF251538),
        Color(0xFF4A2A63),
        Color(0xFF12C7B7),
      ],
    ),
    _HomeBanner(
      title: 'Official Events',
      subtitle: 'Events are available through banners and notifications.',
      icon: Icons.workspace_premium_rounded,
      gradient: [
        Color(0xFFC99A3B),
        Color(0xFFE84C72),
        Color(0xFF4A2A63),
      ],
    ),
  ];

  final List<_RoomData> _rooms = const [
    _RoomData(
      id: 'VM120451',
      name: 'Late Night Chill',
      subtitle: 'Soft talks, music and Telugu vibes',
      language: 'Telugu',
      mode: 'Open',
      type: 'Music',
      onlineCount: 248,
      trendingScore: 9820,
      followedFriendsInside: ['Riya', 'Aman'],
    ),
    _RoomData(
      id: 'VM881029',
      name: 'Hyderabad Friends Adda',
      subtitle: 'Casual chat room for Telugu friends',
      language: 'Telugu',
      mode: 'Locked',
      type: 'Chat',
      onlineCount: 186,
      trendingScore: 8740,
      followedFriendsInside: ['Meera'],
    ),
    _RoomData(
      id: 'VM772190',
      name: 'Secret Star Vibe',
      subtitle: 'Private hidden room',
      language: 'Hindi',
      mode: 'Secret Vibe',
      type: 'Chat',
      onlineCount: 91,
      trendingScore: 8321,
      followedFriendsInside: ['Kiran'],
    ),
    _RoomData(
      id: 'VM551482',
      name: 'Bollywood Vibe Sync',
      subtitle: 'Hindi songs, live energy and gifts',
      language: 'Hindi',
      mode: 'Vibe Sync',
      type: 'Music',
      onlineCount: 452,
      trendingScore: 12940,
      followedFriendsInside: ['Riya', 'Kiran', 'Aman'],
    ),
    _RoomData(
      id: 'VM660410',
      name: 'English Talk Lounge',
      subtitle: 'Practice English and meet new friends',
      language: 'English',
      mode: 'Open',
      type: 'Chat',
      onlineCount: 129,
      trendingScore: 6540,
      followedFriendsInside: [],
    ),
    _RoomData(
      id: 'VM330821',
      name: 'Tamil Melody Room',
      subtitle: 'Tamil songs and friendly talks',
      language: 'Tamil',
      mode: 'Open',
      type: 'Music',
      onlineCount: 214,
      trendingScore: 7360,
      followedFriendsInside: ['Meera'],
    ),
    _RoomData(
      id: 'VM909112',
      name: 'Gaming Voice Squad',
      subtitle: 'Find teammates and game friends',
      language: 'English',
      mode: 'Open',
      type: 'Gaming',
      onlineCount: 318,
      trendingScore: 9102,
      followedFriendsInside: ['Aman'],
    ),
    _RoomData(
      id: 'VM741902',
      name: 'Malayalam Friends Cafe',
      subtitle: 'Friendly Malayalam room',
      language: 'Malayalam',
      mode: 'Members Only',
      type: 'Chat',
      onlineCount: 104,
      trendingScore: 5121,
      followedFriendsInside: ['Nivin'],
    ),
    _RoomData(
      id: 'VM624812',
      name: 'PK Battle Arena',
      subtitle: 'Voice room with PK-style energy',
      language: 'Hindi',
      mode: 'Open',
      type: 'PK',
      onlineCount: 502,
      trendingScore: 15420,
      followedFriendsInside: ['Riya'],
    ),
    _RoomData(
      id: 'VM882761',
      name: 'Kannada Chill House',
      subtitle: 'Late night Kannada live room',
      language: 'Kannada',
      mode: 'Locked',
      type: 'Chat',
      onlineCount: 88,
      trendingScore: 3980,
      followedFriendsInside: ['Kavya'],
    ),
    _RoomData(
      id: 'VM771541',
      name: 'Bengali Music Night',
      subtitle: 'Songs, poems and friendly voices',
      language: 'Bengali',
      mode: 'Vibe Sync',
      type: 'Music',
      onlineCount: 176,
      trendingScore: 6891,
      followedFriendsInside: ['Kiran'],
    ),
    _RoomData(
      id: 'VM445129',
      name: 'Friends Only Lounge',
      subtitle: 'Private member-based talk room',
      language: 'English',
      mode: 'Members Only',
      type: 'Chat',
      onlineCount: 67,
      trendingScore: 2870,
      followedFriendsInside: ['Meera'],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      final nearBottom = _scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 420;

      if (nearBottom && _visibleRoomCount < _filteredRooms.length) {
        setState(() {
          _visibleRoomCount =
              (_visibleRoomCount + 4).clamp(0, _filteredRooms.length);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _lockPasswordController.dispose();
    super.dispose();
  }

  bool get _canManageHomeBanners {
    final dynamic activeUser = widget.user ?? widget.currentUser;

    try {
      final primaryRole = activeUser?.primaryRole?.toString().toLowerCase();
      final roles = activeUser?.roles;

      if (primaryRole == 'founder_owner' ||
          primaryRole == 'super_owner' ||
          primaryRole == 'owner') {
        return true;
      }

      if (roles is Iterable) {
        return roles.any((role) {
          final normalized = role.toString().toLowerCase();
          return normalized == 'founder_owner' ||
              normalized == 'super_owner' ||
              normalized == 'owner';
        });
      }
    } catch (_) {
      return false;
    }

    return false;
  }

  List<_RoomData> get _publicOpenRooms {
    return _rooms.where((room) => room.isPublicOpen).toList();
  }

  List<_RoomData> get _followingExceptionRooms {
    return _rooms.where((room) {
      return room.followedFriendsInside.isNotEmpty && !room.isSecretVibe;
    }).toList();
  }

  List<_RoomData> get _filteredRooms {
    final sourceRooms =
        _selectedCategory == 'Following' ? _followingExceptionRooms : _publicOpenRooms;

    final filtered = sourceRooms.where((room) {
      final categoryMatch = _selectedCategory == 'Trending' ||
          _selectedCategory == 'Following' ||
          room.type == _selectedCategory;

      final languageMatch =
          _selectedLanguage == 'All' || room.language == _selectedLanguage;

      return categoryMatch && languageMatch;
    }).toList();

    filtered.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    return filtered;
  }

  List<_RoomData> get _visibleRooms {
    final rooms = _filteredRooms;
    return rooms.take(_visibleRoomCount.clamp(0, rooms.length)).toList();
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

  void _openRoom(_RoomData room) {
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

  void _enterRoom(_RoomData room) {
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

  void _openLockedRoomSheet(_RoomData room) {
    _lockPasswordController.clear();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        bool passwordVisible = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _HomeSheet(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SheetHandle(),
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
                    controller: _lockPasswordController,
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
                        child: _SecondaryButton(
                          text: 'Cancel',
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PrimaryButton(
                          text: 'Enter',
                          icon: Icons.lock_open_rounded,
                          onTap: () {
                            final password =
                                _lockPasswordController.text.trim();

                            if (password != '1234') {
                              _toast('Wrong password. Use 1234 for mock room.');
                              return;
                            }

                            Navigator.pop(context);
                            _enterRoom(room);
                          },
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
    );
  }

  void _openLanguageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _HomeSheet(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Room language',
                      style: TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF4A2A63),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final language = _languages[index];
                    final selected = language == _selectedLanguage;

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.language_rounded,
                        color: selected
                            ? const Color(0xFF12C7B7)
                            : const Color(0xFF7B6A86),
                      ),
                      title: Text(
                        language,
                        style: TextStyle(
                          color: const Color(0xFF251538),
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedLanguage = language;
                          _visibleRoomCount = 6;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _seeAllRooms() {
    setState(() {
      _visibleRoomCount = _filteredRooms.length;
    });

    if (_selectedCategory == 'Following') {
      _toast('Showing all rooms where followed users are active');
      return;
    }

    _toast('Showing all public open rooms');
  }

  @override
  Widget build(BuildContext context) {
    final visibleRooms = _visibleRooms;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildBanner()),
            SliverToBoxAdapter(child: _buildFilters()),
            SliverToBoxAdapter(child: _buildRoomSectionHeader()),
            if (visibleRooms.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState())
            else
              SliverList.builder(
                itemCount: visibleRooms.length,
                itemBuilder: (context, index) {
                  final room = visibleRooms[index];
                  return _RoomCard(
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
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 14),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEDE3D7)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF251538).withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  'assets/images/branding/vibe_match_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF12C7B7),
                            Color(0xFF8C5CF6),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Text(
                          'VM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Vibe Match',
              style: TextStyle(
                color: Color(0xFF251538),
                fontSize: 29,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.7,
              ),
            ),
          ),
          _HeaderButton(
            icon: Icons.search_rounded,
            onTap: () => _toast('Search opened'),
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            icon: Icons.notifications_rounded,
            onTap: () => _toast('Notifications opened'),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      height: 166,
      child: PageView.builder(
        itemCount: _banners.length,
        onPageChanged: (index) {
          setState(() => _selectedBannerIndex = index);
        },
        itemBuilder: (context, index) {
          final banner = _banners[index];

          return GestureDetector(
            onTap: () => _toast('${banner.title} opened'),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: banner.gradient,
                ),
                boxShadow: [
                  BoxShadow(
                    color: banner.gradient.first.withValues(alpha: 0.25),
                    blurRadius: 26,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -8,
                    bottom: -18,
                    child: Icon(
                      banner.icon,
                      size: 112,
                      color: Colors.white.withValues(alpha: 0.13),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.17),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Official Highlight',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        banner.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        banner.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12.5,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          ...List.generate(
                            _banners.length,
                            (dotIndex) => AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 5),
                              width:
                                  dotIndex == _selectedBannerIndex ? 18 : 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: dotIndex == _selectedBannerIndex
                                      ? 0.95
                                      : 0.38,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (_canManageHomeBanners)
                            GestureDetector(
                              onTap: () => _toast(
                                'Banner management opened for official account',
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.17),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.admin_panel_settings_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'Manage',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Column(
        children: [
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _selectedCategory;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _visibleRoomCount = 6;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF251538) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF251538)
                            : const Color(0xFFEDE3D7),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF251538).withValues(
                            alpha: selected ? 0.13 : 0.04,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        category,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF4A2A63),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openLanguageSheet,
                  child: Container(
                    height: 46,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEDE3D7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.language_rounded,
                          color: Color(0xFF8C5CF6),
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'Language',
                          style: TextStyle(
                            color: Color(0xFF7B6A86),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            _selectedLanguage,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF251538),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF4A2A63),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _seeAllRooms,
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12C7B7),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFF12C7B7).withValues(alpha: 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'See All',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSectionHeader() {
    final total = _filteredRooms.length;
    final title = _selectedCategory == 'Following'
        ? 'Following rooms'
        : _selectedCategory == 'Trending'
            ? 'Trending rooms'
            : '$_selectedCategory rooms';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            '$total found',
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final message = _selectedCategory == 'Following'
        ? 'No followed users are active in visible rooms right now.'
        : 'Try another category or language.';

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF8C5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.public_off_rounded,
              color: Color(0xFF8C5CF6),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'No rooms found',
            style: TextStyle(
              color: Color(0xFF251538),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7B6A86),
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBanner {
  const _HomeBanner({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
}

class _RoomData {
  const _RoomData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.language,
    required this.mode,
    required this.type,
    required this.onlineCount,
    required this.trendingScore,
    required this.followedFriendsInside,
  });

  final String id;
  final String name;
  final String subtitle;
  final String language;
  final String mode;
  final String type;
  final int onlineCount;
  final int trendingScore;
  final List<String> followedFriendsInside;

  bool get isPublicOpen {
    return mode.trim().toLowerCase() == 'open';
  }

  bool get isSecretVibe {
    return mode.trim().toLowerCase().contains('secret');
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.rank,
    required this.onTap,
  });

  final _RoomData room;
  final int rank;
  final VoidCallback onTap;

  Color get _modeColor {
    final mode = room.mode.toLowerCase();

    if (mode.contains('secret')) return const Color(0xFF8C5CF6);
    if (mode.contains('lock')) return const Color(0xFFC99A3B);
    if (mode.contains('member')) return const Color(0xFFE84C72);
    if (mode.contains('sync')) return const Color(0xFF12C7B7);

    return const Color(0xFF12C7B7);
  }

  IconData get _modeIcon {
    final mode = room.mode.toLowerCase();

    if (mode.contains('secret')) return Icons.visibility_off_rounded;
    if (mode.contains('lock')) return Icons.lock_rounded;
    if (mode.contains('member')) return Icons.workspace_premium_rounded;
    if (mode.contains('sync')) return Icons.graphic_eq_rounded;

    return Icons.public_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final friendsText = room.followedFriendsInside.isEmpty
        ? 'No followed friends inside'
        : '${room.followedFriendsInside.join(', ')} inside';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFEDE3D7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.045),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _RoomAvatar(room: room, size: 66),
                Positioned(
                  left: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF251538),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF251538),
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _modeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_modeIcon, color: _modeColor, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              room.mode,
                              style: TextStyle(
                                color: _modeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    room.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7B6A86),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _RoomMiniPill(
                        icon: Icons.language_rounded,
                        text: room.language,
                      ),
                      _RoomMiniPill(
                        icon: Icons.people_rounded,
                        text: '${room.onlineCount}',
                      ),
                      _RoomMiniPill(
                        icon: Icons.local_fire_department_rounded,
                        text: '${room.trendingScore}',
                      ),
                      _RoomMiniPill(
                        icon: Icons.category_rounded,
                        text: room.type,
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          friendsText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF4A2A63),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF7B6A86),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({
    required this.room,
    required this.size,
  });

  final _RoomData room;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mode = room.mode.toLowerCase();

    List<Color> colors = const [
      Color(0xFF12C7B7),
      Color(0xFF8C5CF6),
    ];

    if (mode.contains('secret')) {
      colors = const [
        Color(0xFF251538),
        Color(0xFF8C5CF6),
      ];
    } else if (mode.contains('lock')) {
      colors = const [
        Color(0xFFC99A3B),
        Color(0xFF4A2A63),
      ];
    } else if (mode.contains('sync')) {
      colors = const [
        Color(0xFF12C7B7),
        Color(0xFFE84C72),
      ];
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.34),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.23),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        room.type == 'Gaming'
            ? Icons.sports_esports_rounded
            : room.type == 'PK'
                ? Icons.bolt_rounded
                : room.type == 'Music'
                    ? Icons.music_note_rounded
                    : Icons.graphic_eq_rounded,
        color: Colors.white,
        size: size * 0.42,
      ),
    );
  }
}

class _RoomMiniPill extends StatelessWidget {
  const _RoomMiniPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF7F1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFEDE3D7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF7B6A86), size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF4A2A63),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEDE3D7)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF251538).withValues(alpha: 0.045),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(0xFF4A2A63),
          size: 21,
        ),
      ),
    );
  }
}

class _HomeSheet extends StatelessWidget {
  const _HomeSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(
        18,
        10,
        18,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: const Color(0xFFE0D5CB),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF12C7B7),
              Color(0xFF8C5CF6),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF12C7B7).withValues(alpha: 0.24),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEDE3D7)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF4A2A63), size: 20),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF4A2A63),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}