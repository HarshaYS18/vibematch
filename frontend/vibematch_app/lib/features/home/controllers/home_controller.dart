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
  String selectedCategory = 'Trending';
  String selectedLanguage = 'All';
  bool isLoadingHomeChrome = false;
  String? bannerErrorMessage;
  HomeRoom? myCreatedRoom;

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

  List<HomeRoom> get rooms => const [];

  List<HomeRoom> get filteredRooms => const [];

  List<HomeRoom> get visibleRooms => const [];

  bool get hasNetworkError => false;

  bool get usingBackendRooms => false;

  bool get isLoadingRooms => false;

  String? get loadErrorMessage => null;

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
  }

  Future<void> loadTrendingRooms({bool silent = false}) async {}

  Future<void> loadRooms({bool silent = false}) async {}

  Future<void> refreshAll() async {
    await loadHomeChrome();
  }

  void onScrollNearBottom(ScrollController scrollController) {}

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
    notifyListeners();
  }

  void selectLanguage(String language) {
    selectedLanguage = language;
    notifyListeners();
  }

  void seeAllRooms() {}

  Future<void> retryLoadingRooms() async {}

  int _clampIndex(int value, int length) {
    if (length <= 0) return 0;
    if (value < 0) return 0;
    if (value >= length) return length - 1;
    return value;
  }

  @override
  void dispose() {
    _repository.close();
    super.dispose();
  }
}
