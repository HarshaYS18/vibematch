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
  bool isLoadingHomeChrome = false;
  String? loadErrorMessage;
  String? bannerErrorMessage;
  HomeRoom? myCreatedRoom;

  List<HomeRoom> _backendRooms = const [];
  List<HomeBanner> _eventBanners = const [];
  List<HomeBanner> _policyBanners = const [];

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

  List<HomeBanner> get banners => _eventBanners;

  List<HomeBanner> get policyBanners => _policyBanners;

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

  Future<void> loadHomeChrome() async {
    if (isLoadingHomeChrome) return;
    isLoadingHomeChrome = true;
    bannerErrorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object?>([
        _repository.fetchMyCreatedRoom(),
        _repository.fetchHomeBanners(placement: 'event'),
        _repository.fetchHomeBanners(placement: 'policy_rules'),
      ]);

      myCreatedRoom = results[0] as HomeRoom?;
      _eventBanners = (results[1] as List<HomeBanner>?) ?? const [];
      _policyBanners = (results[2] as List<HomeBanner>?) ?? const [];
      selectedBannerIndex = selectedBannerIndex.clamp(0, _eventBanners.isEmpty ? 0 : _eventBanners.length - 1);
      selectedPolicyBannerIndex = selectedPolicyBannerIndex.clamp(0, _policyBanners.isEmpty ? 0 : _policyBanners.length - 1);
      bannerErrorMessage = null;
    } catch (_) {
      myCreatedRoom = null;
      _eventBanners = const [];
      _policyBanners = const [];
      bannerErrorMessage = 'Could not load home banners or created room. Pull to refresh.';
    } finally {
      isLoadingHomeChrome = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterRoomCreation() async {
    await loadHomeChrome();
    await loadRooms();
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

  Future<void> refreshAll() async {
    await Future.wait([loadHomeChrome(), loadRooms()]);
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
