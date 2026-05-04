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
  HomeRoom? myCreatedRoom;

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

  List<HomeRoom> get rooms => _backendRooms;

  bool get hasNetworkError => loadErrorMessage != null;

  bool get usingBackendRooms => _backendRooms.isNotEmpty && !hasNetworkError;

  List<HomeRoom> get publicOpenRooms {
    return rooms.where((room) => room.isPublicOpen || room.isLocked).toList();
  }

  List<HomeRoom> get followingExceptionRooms {
    return rooms.where((room) => room.followedFriendsInside.isNotEmpty && !room.isSecretVibe).toList();
  }

  List<HomeRoom> get filteredRooms {
    if (hasNetworkError) return const [];

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

  void ensureMockCreatedRoom() {
    myCreatedRoom ??= HomeRoom(
      id: 'VM${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      name: 'My Vibe Room',
      subtitle: 'Your created live room',
      language: selectedLanguage == 'All' ? 'Telugu' : selectedLanguage,
      mode: 'Open',
      type: 'Chat',
      onlineCount: 1,
      trendingScore: 0,
      followedFriendsInside: const [],
    );
    notifyListeners();
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
      loadErrorMessage = 'Network error. Please check your connection and try again.';
    } finally {
      isLoadingRooms = false;
      visibleRoomCount = 6;
      notifyListeners();
    }
  }

  void onScrollNearBottom(ScrollController scrollController) {
    if (!scrollController.hasClients || hasNetworkError) return;
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

  Future<void> retryLoadingRooms() {
    return loadTrendingRooms();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
