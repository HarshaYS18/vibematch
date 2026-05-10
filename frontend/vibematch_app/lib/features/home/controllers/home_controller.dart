import 'package:flutter/material.dart';

import '../data/home_repository.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';

class HomeController extends ChangeNotifier {
  HomeController({HomeRepository? repository})
      : _repository = repository ?? HomeRepository();

  final HomeRepository _repository;

  int selectedBannerIndex = 0;
  int selectedPolicyBannerIndex = 0;
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
      id: 'event_weekend_001',
      title: 'Weekend Event',
      fallbackIcon: Icons.celebration_rounded,
      fallbackGradient: [Color(0xFFE84C72), Color(0xFF8C5CF6)],
    ),
    HomeBanner(
      id: 'promo_recharge_001',
      title: 'Recharge Promo',
      fallbackIcon: Icons.bolt_rounded,
      fallbackGradient: [Color(0xFFC99A3B), Color(0xFFE84C72)],
    ),
    HomeBanner(
      id: 'event_vibes_001',
      title: 'Vibes Event',
      fallbackIcon: Icons.auto_awesome_rounded,
      fallbackGradient: [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    ),
  ];

  final List<HomeBanner> policyBanners = const [
    HomeBanner(
      id: 'policy_rules_001',
      title: 'Rules & Regulations',
      fallbackIcon: Icons.rule_rounded,
      fallbackGradient: [Color(0xFF251538), Color(0xFF4A2A63)],
    ),
    HomeBanner(
      id: 'policy_safety_001',
      title: 'Safety Policy',
      fallbackIcon: Icons.verified_user_rounded,
      fallbackGradient: [Color(0xFF4A2A63), Color(0xFF12C7B7)],
    ),
  ];

  List<HomeRoom> get rooms => _backendRooms;

  bool get hasNetworkError => loadErrorMessage != null;

  bool get usingBackendRooms => _backendRooms.isNotEmpty && !hasNetworkError;

  List<HomeRoom> get filteredRooms {
    if (hasNetworkError) return const [];

    final filtered = rooms.where((room) {
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

  Future<void> refreshAfterRoomCreation() async {
    myCreatedRoom = null;
    await loadRooms();
  }

  void ensureMockCreatedRoom() {
    myCreatedRoom = null;
    notifyListeners();
  }

  Future<void> loadTrendingRooms({bool silent = false}) => loadRooms(silent: silent);

  Future<void> loadRooms({bool silent = false}) async {
    if (isLoadingRooms) return;

    isLoadingRooms = true;
    if (!silent) loadErrorMessage = null;
    notifyListeners();

    try {
      final categoryForBackend = selectedCategory == 'Trending' || selectedCategory == 'Following'
          ? null
          : selectedCategory;
      final languageForBackend = selectedLanguage == 'All' ? null : selectedLanguage;

      final fetchedRooms = selectedCategory == 'Following'
          ? await _repository.fetchFollowingRooms(
              language: languageForBackend,
              category: categoryForBackend,
              limit: 50,
            )
          : await _repository.fetchTrendingRooms(
              language: languageForBackend,
              category: categoryForBackend,
              limit: 50,
            );

      _backendRooms = fetchedRooms;
      loadErrorMessage = null;
    } catch (_) {
      _backendRooms = const [];
      loadErrorMessage = selectedCategory == 'Following'
          ? 'Network error. Could not load following rooms. Login again or try later.'
          : 'Network error. Please check your connection and try again.';
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

  void selectPolicyBanner(int index) {
    selectedPolicyBannerIndex = index;
    notifyListeners();
  }

  void selectCategory(String category) {
    selectedCategory = category;
    visibleRoomCount = 6;
    notifyListeners();
    loadRooms(silent: true);
  }

  void selectLanguage(String language) {
    selectedLanguage = language;
    visibleRoomCount = 6;
    notifyListeners();
    loadRooms(silent: true);
  }

  void seeAllRooms() {
    visibleRoomCount = filteredRooms.length;
    notifyListeners();
  }

  Future<void> retryLoadingRooms() {
    return loadRooms();
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
