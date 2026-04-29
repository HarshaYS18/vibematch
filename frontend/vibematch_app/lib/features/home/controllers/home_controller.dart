import 'package:flutter/material.dart';

import '../data/home_repository.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';

class HomeController extends ChangeNotifier {
  HomeController({HomeRepository? repository})
      : _repository = repository ?? HomeRepository();

  final HomeRepository _repository;

  int selectedBannerIndex = 0;
  int visibleRoomCount = 6;
  String selectedCategory = 'Trending';
  String selectedLanguage = 'All';
  bool isLoadingRooms = false;
  String? loadErrorMessage;

  List<HomeRoom> _backendRooms = const [];

  final List<String> categories = const [
    'Trending',
    'Following',
    'Music',
    'Gaming',
    'Chat',
    'PK',
  ];

  final List<String> languages = const [
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

  final List<HomeBanner> banners = const [
    HomeBanner(
      title: 'Tonight’s Premium Rooms',
      subtitle: 'Join trending voice rooms with live seats and gifts.',
      icon: Icons.graphic_eq_rounded,
      gradient: [Color(0xFF12C7B7), Color(0xFF8C5CF6), Color(0xFFE84C72)],
      action: HomeBannerAction.openTrendingRooms,
    ),
    HomeBanner(
      title: 'Vibe Sync Rooms',
      subtitle: 'Music-style live rooms with animated mood and energy.',
      icon: Icons.waves_rounded,
      gradient: [Color(0xFF251538), Color(0xFF4A2A63), Color(0xFF12C7B7)],
      action: HomeBannerAction.openVibeSyncRooms,
    ),
    HomeBanner(
      title: 'Official Events',
      subtitle: 'Events are available through banners and notifications.',
      icon: Icons.workspace_premium_rounded,
      gradient: [Color(0xFFC99A3B), Color(0xFFE84C72), Color(0xFF4A2A63)],
      action: HomeBannerAction.openEvents,
    ),
  ];

  final List<HomeRoom> mockRooms = const [
    HomeRoom(id: 'VM120451', name: 'Late Night Chill', subtitle: 'Soft talks, music and Telugu vibes', language: 'Telugu', mode: 'Open', type: 'Music', onlineCount: 248, trendingScore: 9820, followedFriendsInside: ['Riya', 'Aman']),
    HomeRoom(id: 'VM881029', name: 'Hyderabad Friends Adda', subtitle: 'Casual chat room for Telugu friends', language: 'Telugu', mode: 'Locked', type: 'Chat', onlineCount: 186, trendingScore: 8740, followedFriendsInside: ['Meera']),
    HomeRoom(id: 'VM772190', name: 'Secret Star Vibe', subtitle: 'Private hidden room', language: 'Hindi', mode: 'Secret Vibe', type: 'Chat', onlineCount: 91, trendingScore: 8321, followedFriendsInside: ['Kiran']),
    HomeRoom(id: 'VM551482', name: 'Bollywood Vibe Sync', subtitle: 'Hindi songs, live energy and gifts', language: 'Hindi', mode: 'Vibe Sync', type: 'Music', onlineCount: 452, trendingScore: 12940, followedFriendsInside: ['Riya', 'Kiran', 'Aman']),
    HomeRoom(id: 'VM660410', name: 'English Talk Lounge', subtitle: 'Practice English and meet new friends', language: 'English', mode: 'Open', type: 'Chat', onlineCount: 129, trendingScore: 6540, followedFriendsInside: []),
    HomeRoom(id: 'VM330821', name: 'Tamil Melody Room', subtitle: 'Tamil songs and friendly talks', language: 'Tamil', mode: 'Open', type: 'Music', onlineCount: 214, trendingScore: 7360, followedFriendsInside: ['Meera']),
    HomeRoom(id: 'VM909112', name: 'Gaming Voice Squad', subtitle: 'Find teammates and game friends', language: 'English', mode: 'Open', type: 'Gaming', onlineCount: 318, trendingScore: 9102, followedFriendsInside: ['Aman']),
    HomeRoom(id: 'VM741902', name: 'Malayalam Friends Cafe', subtitle: 'Friendly Malayalam room', language: 'Malayalam', mode: 'Members Only', type: 'Chat', onlineCount: 104, trendingScore: 5121, followedFriendsInside: ['Nivin']),
    HomeRoom(id: 'VM624812', name: 'PK Battle Arena', subtitle: 'Voice room with PK-style energy', language: 'Hindi', mode: 'Open', type: 'PK', onlineCount: 502, trendingScore: 15420, followedFriendsInside: ['Riya']),
    HomeRoom(id: 'VM882761', name: 'Kannada Chill House', subtitle: 'Late night Kannada live room', language: 'Kannada', mode: 'Locked', type: 'Chat', onlineCount: 88, trendingScore: 3980, followedFriendsInside: ['Kavya']),
    HomeRoom(id: 'VM771541', name: 'Bengali Music Night', subtitle: 'Songs, poems and friendly voices', language: 'Bengali', mode: 'Vibe Sync', type: 'Music', onlineCount: 176, trendingScore: 6891, followedFriendsInside: ['Kiran']),
    HomeRoom(id: 'VM445129', name: 'Friends Only Lounge', subtitle: 'Private member-based talk room', language: 'English', mode: 'Members Only', type: 'Chat', onlineCount: 67, trendingScore: 2870, followedFriendsInside: ['Meera']),
  ];

  List<HomeRoom> get rooms {
    return _backendRooms.isEmpty ? mockRooms : _backendRooms;
  }

  bool get usingBackendRooms => _backendRooms.isNotEmpty;

  List<HomeRoom> get publicOpenRooms {
    return rooms.where((room) => room.isPublicOpen || room.isLocked).toList();
  }

  List<HomeRoom> get followingExceptionRooms {
    return rooms.where((room) => room.followedFriendsInside.isNotEmpty && !room.isSecretVibe).toList();
  }

  List<HomeRoom> get filteredRooms {
    final sourceRooms = selectedCategory == 'Following' ? followingExceptionRooms : publicOpenRooms;
    final filtered = sourceRooms.where((room) {
      final categoryMatch = selectedCategory == 'Trending' || selectedCategory == 'Following' || room.type == selectedCategory;
      final languageMatch = selectedLanguage == 'All' || room.language == selectedLanguage;
      return categoryMatch && languageMatch;
    }).toList();

    filtered.sort((a, b) => b.trendingScore.compareTo(a.trendingScore));
    return filtered;
  }

  List<HomeRoom> get visibleRooms {
    final rooms = filteredRooms;
    return rooms.take(visibleRoomCount.clamp(0, rooms.length)).toList();
  }

  Future<void> loadTrendingRooms({bool silent = false}) async {
    if (isLoadingRooms) return;

    isLoadingRooms = true;
    if (!silent) loadErrorMessage = null;
    notifyListeners();

    try {
      final fetchedRooms = await _repository.fetchTrendingRooms(
        language: selectedLanguage == 'All' ? null : selectedLanguage,
        category: selectedCategory == 'Trending' || selectedCategory == 'Following'
            ? null
            : selectedCategory,
        limit: 50,
      );

      _backendRooms = fetchedRooms;
      loadErrorMessage = null;
    } catch (_) {
      _backendRooms = const [];
      loadErrorMessage = 'Backend unavailable. Showing local demo rooms.';
    } finally {
      isLoadingRooms = false;
      visibleRoomCount = 6;
      notifyListeners();
    }
  }

  void onScrollNearBottom(ScrollController scrollController) {
    if (!scrollController.hasClients) return;
    final nearBottom = scrollController.position.pixels > scrollController.position.maxScrollExtent - 420;
    if (nearBottom && visibleRoomCount < filteredRooms.length) {
      visibleRoomCount = (visibleRoomCount + 4).clamp(0, filteredRooms.length);
      notifyListeners();
    }
  }

  void selectBanner(int index) {
    selectedBannerIndex = index;
    notifyListeners();
  }

  void selectCategory(String category) {
    selectedCategory = category;
    visibleRoomCount = 6;
    notifyListeners();
    loadTrendingRooms(silent: true);
  }

  void selectLanguage(String language) {
    selectedLanguage = language;
    visibleRoomCount = 6;
    notifyListeners();
    loadTrendingRooms(silent: true);
  }

  void seeAllRooms() {
    visibleRoomCount = filteredRooms.length;
    notifyListeners();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
