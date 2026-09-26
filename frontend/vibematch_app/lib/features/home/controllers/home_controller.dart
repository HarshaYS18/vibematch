import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_repository.dart';
import '../models/home_banner.dart';
import '../models/home_room.dart';

const Object _homeUnset = Object();

class HomeState {
  const HomeState({
    this.selectedBannerIndex = 0,
    this.selectedPolicyBannerIndex = 0,
    this.visibleRoomCount = 8,
    this.selectedCategory = 'Trending',
    this.selectedLanguage = 'All',
    this.isLoadingRooms = false,
    this.isLoadingHomeChrome = false,
    this.isQuickMatching = false,
    this.loadErrorMessage,
    this.bannerErrorMessage,
    this.myCreatedRoom,
    this.backendRooms = const <HomeRoom>[],
    this.eventBanners = const <HomeBanner>[],
    this.policyBanners = const <HomeBanner>[],
  });

  final int selectedBannerIndex;
  final int selectedPolicyBannerIndex;
  final int visibleRoomCount;
  final String selectedCategory;
  final String selectedLanguage;
  final bool isLoadingRooms;
  final bool isLoadingHomeChrome;
  final bool isQuickMatching;
  final String? loadErrorMessage;
  final String? bannerErrorMessage;
  final HomeRoom? myCreatedRoom;
  final List<HomeRoom> backendRooms;
  final List<HomeBanner> eventBanners;
  final List<HomeBanner> policyBanners;

  bool get hasNetworkError => loadErrorMessage != null;

  List<HomeRoom> get filteredRooms {
    if (hasNetworkError) return const <HomeRoom>[];
    final filtered = backendRooms.where((room) {
      final languageMatch =
          selectedLanguage == 'All' || room.language == selectedLanguage;
      if (!languageMatch) return false;
      if (selectedCategory == 'Trending') {
        return room.isPublicOpen && room.onlineCount > 0;
      }
      return true;
    }).toList(growable: false)
      ..sort((a, b) {
        final onlineCompare = b.onlineCount.compareTo(a.onlineCount);
        if (onlineCompare != 0) return onlineCompare;
        return b.trendingScore.compareTo(a.trendingScore);
      });
    return filtered;
  }

  List<HomeRoom> get visibleRooms {
    final filtered = filteredRooms;
    final count = visibleRoomCount.clamp(0, filtered.length);
    return filtered.take(count).toList(growable: false);
  }

  HomeState copyWith({
    int? selectedBannerIndex,
    int? selectedPolicyBannerIndex,
    int? visibleRoomCount,
    String? selectedCategory,
    String? selectedLanguage,
    bool? isLoadingRooms,
    bool? isLoadingHomeChrome,
    bool? isQuickMatching,
    Object? loadErrorMessage = _homeUnset,
    Object? bannerErrorMessage = _homeUnset,
    Object? myCreatedRoom = _homeUnset,
    List<HomeRoom>? backendRooms,
    List<HomeBanner>? eventBanners,
    List<HomeBanner>? policyBanners,
  }) {
    return HomeState(
      selectedBannerIndex: selectedBannerIndex ?? this.selectedBannerIndex,
      selectedPolicyBannerIndex:
          selectedPolicyBannerIndex ?? this.selectedPolicyBannerIndex,
      visibleRoomCount: visibleRoomCount ?? this.visibleRoomCount,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      isLoadingRooms: isLoadingRooms ?? this.isLoadingRooms,
      isLoadingHomeChrome: isLoadingHomeChrome ?? this.isLoadingHomeChrome,
      isQuickMatching: isQuickMatching ?? this.isQuickMatching,
      loadErrorMessage: identical(loadErrorMessage, _homeUnset)
          ? this.loadErrorMessage
          : loadErrorMessage as String?,
      bannerErrorMessage: identical(bannerErrorMessage, _homeUnset)
          ? this.bannerErrorMessage
          : bannerErrorMessage as String?,
      myCreatedRoom: identical(myCreatedRoom, _homeUnset)
          ? this.myCreatedRoom
          : myCreatedRoom as HomeRoom?,
      backendRooms: backendRooms ?? this.backendRooms,
      eventBanners: eventBanners ?? this.eventBanners,
      policyBanners: policyBanners ?? this.policyBanners,
    );
  }
}

class HomeController extends AutoDisposeNotifier<HomeState> {
  late final HomeRepository _repository;

  @override
  HomeState build() {
    _repository = HomeRepository();
    ref.onDispose(_repository.close);
    return const HomeState();
  }

  static const List<String> categories = <String>[
    'Trending',
    'Following',
  ];

  static const List<String> languages = <String>[
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

  List<String> get availableCategories => categories;
  List<String> get availableLanguages => languages;
  HomeRoom? get myCreatedRoom => state.myCreatedRoom;
  String get selectedLanguage => state.selectedLanguage;
  String get selectedCategory => state.selectedCategory;

  Future<void> loadHomeChrome() async {
    if (state.isLoadingHomeChrome) return;
    state = state.copyWith(
      isLoadingHomeChrome: true,
      bannerErrorMessage: null,
    );

    try {
      final composite = await _repository.fetchHomeChromeComposite();
      final eventBanners = composite.eventBanners;
      final policyBanners = composite.policyBanners;
      state = state.copyWith(
        myCreatedRoom: composite.myCreatedRoom,
        eventBanners: eventBanners,
        policyBanners: policyBanners,
        selectedBannerIndex:
            _clampIndex(state.selectedBannerIndex, eventBanners.length),
        selectedPolicyBannerIndex:
            _clampIndex(state.selectedPolicyBannerIndex, policyBanners.length),
        bannerErrorMessage: composite.hasPartialErrors
            ? 'Some home content could not be refreshed.'
            : null,
      );
    } catch (_) {
      state = state.copyWith(
        myCreatedRoom: null,
        eventBanners: const <HomeBanner>[],
        policyBanners: const <HomeBanner>[],
        bannerErrorMessage: 'Could not load home banners. Pull to refresh.',
      );
    } finally {
      state = state.copyWith(isLoadingHomeChrome: false);
    }
  }

  Future<void> refreshAfterRoomCreation() async {
    await loadHomeChrome();
    await loadRooms();
  }

  Future<void> loadTrendingRooms({bool silent = false}) =>
      loadRooms(silent: silent);

  Future<void> loadRooms({bool silent = false}) async {
    if (state.isLoadingRooms) return;
    state = state.copyWith(
      isLoadingRooms: true,
      loadErrorMessage: silent ? state.loadErrorMessage : null,
    );

    try {
      final languageForBackend =
          state.selectedLanguage == 'All' ? null : state.selectedLanguage;
      final fetchedRooms = state.selectedCategory == 'Following'
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
      state = state.copyWith(
        backendRooms: fetchedRooms,
        loadErrorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        backendRooms: const <HomeRoom>[],
        loadErrorMessage: 'Could not load rooms. Pull to refresh.',
      );
    } finally {
      state = state.copyWith(
        isLoadingRooms: false,
        visibleRoomCount: 8,
      );
    }
  }

  Future<void> refreshAll() async {
    await Future.wait<void>([loadHomeChrome(), loadRooms()]);
  }

  void onScrollNearBottom(ScrollController scrollController) {
    if (!scrollController.hasClients || state.hasNetworkError) return;
    final nearBottom = scrollController.position.pixels >
        scrollController.position.maxScrollExtent - 420;
    final filteredLength = state.filteredRooms.length;
    if (nearBottom && state.visibleRoomCount < filteredLength) {
      state = state.copyWith(
        visibleRoomCount:
            (state.visibleRoomCount + 5).clamp(0, filteredLength),
      );
    }
  }

  void selectBanner(int index) {
    state = state.copyWith(
      selectedBannerIndex: _clampIndex(index, state.eventBanners.length),
    );
  }

  void selectPolicyBanner(int index) {
    state = state.copyWith(
      selectedPolicyBannerIndex:
          _clampIndex(index, state.policyBanners.length),
    );
  }

  void selectCategory(String category) {
    if (!categories.contains(category)) return;
    state = state.copyWith(
      selectedCategory: category,
      visibleRoomCount: 8,
    );
    loadRooms(silent: true);
  }

  void selectLanguage(String language) {
    if (!languages.contains(language)) return;
    state = state.copyWith(
      selectedLanguage: language,
      visibleRoomCount: 8,
    );
    loadRooms(silent: true);
  }

  void seeAllRooms() {
    state = state.copyWith(visibleRoomCount: state.filteredRooms.length);
  }

  Future<HomeRoom?> quickMatch() async {
    if (state.isQuickMatching) return null;
    state = state.copyWith(isQuickMatching: true);
    try {
      return await _repository.fetchQuickMatch(
        language:
            state.selectedLanguage == 'All' ? null : state.selectedLanguage,
      );
    } finally {
      state = state.copyWith(isQuickMatching: false);
    }
  }

  Future<void> retryLoadingRooms() => loadRooms();

  int _clampIndex(int value, int length) {
    if (length <= 0 || value < 0) return 0;
    if (value >= length) return length - 1;
    return value;
  }
}

final homeControllerProvider =
    NotifierProvider.autoDispose<HomeController, HomeState>(
      HomeController.new,
    );
