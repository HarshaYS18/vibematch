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
  int visibleRoomCount = 8;
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

  bool _isOpenActiveRoom(HomeRoom room) {
    return room.isPublicOpen && room.onlineCount > 0;
  }

  List<HomeRoom> get filteredRooms {
    if (hasNetworkError) return const [];
    final filtered = rooms.where((room) {
      final languageMatch = selectedLanguage == 'All' || room.language == selectedLanguage;
      if (!languageMatch) return false;
      if (selectedCategory == 'Trending') return _isOpenActiveRoom(room);
      return true;
    }).toList();

    filtered.sort((a, b) {
      final onlineCompare = b.onlineCount.compareTo(a.onlineCount);
      if (onlineCompare != 0) return onlineCompare;
      return b.trendingScore.compareTo(a.trendingScore);
    });
    return filtered;
  }

  List<HomeRoom> get visibleRooms {
    final rooms = filteredRooms;
    final count = _clampCount(visibleRoomCount, rooms.length);
    return rooms.take(count).toList();
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
      selectedBannerIndex = _clampIndex(selectedBannerIndex, _eventBanners.length);
      selectedPolicyBannerIndex = _clampIndex(selectedPolicyBannerIndex, _policyBanners.length);
      bannerErrorMessage = null;
    } catch (_) {
      myCreatedRoom = null;
      _eventBanners = const [];
      _policyBanners = const [];
      bannerErrorMessage = 'Could not load home banners. Pull to refresh.';
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
      final languageForBackend = selectedLanguage == 'All' ? null : selectedLanguage;
      final fetchedRooms = selectedCategory == 'Following'
          ? await _repository.fetchFollowingRooms(
              language: languageForBackend,
              category: null,
              limit: 80,
            )
          : await _repository.fetchTrendingRooms(
              language: languageForBackend,
              category: null,
              limit: 80,
            );

      _backendRooms = fetchedRooms;
      loadErrorMessage = null;
    } catch (_) {
      _backendRooms = const [];
      loadErrorMessage = 'Could not load rooms. Pull to refresh.';
    } finally {
      isLoadingRooms = false;
      visibleRoomCount = 8;
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
      final nextCount = visibleRoomCount + 5;
      visibleRoomCount = nextCount > filteredRooms.length ? filteredRooms.length : nextCount;
      notifyListeners();
    }
  }

  void selectBanner(int index) {
    selectedBannerIndex = _clampIndex(index, _eventBanners.length);
    notifyListeners();
  }

  void selectPolicyBanner(int index) {
    selectedPolicyBannerIndex = _clampIndex(index, _policyBanners.length);
    notifyListeners();
  }

  void selectCategory(String category) {
    if (!categories.contains(category)) return;
    selectedCategory = category;
    visibleRoomCount = 8;
    notifyListeners();
    loadRooms(silent: true);
  }

  void selectLanguage(String language) {
    selectedLanguage = language;
    visibleRoomCount = 8;
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

  int _clampIndex(int value, int length) {
    if (length <= 0) return 0;
    if (value < 0) return 0;
    if (value >= length) return length - 1;
    return value;
  }

  int _clampCount(int value, int max) {
    if (max <= 0 || value <= 0) return 0;
    return value > max ? max : value;
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
