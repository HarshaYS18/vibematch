import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/search_api_service.dart';
import '../models/search_result_item.dart';
import '../models/search_result_type.dart';

const Object _searchUnset = Object();

class VibeSearchState {
  const VibeSearchState({
    this.query = '',
    this.selectedCategory = SearchResultCategory.all,
    this.recentSearches = const <String>[],
    this.results = const <SearchResultItem>[],
    this.isLoading = false,
    this.errorMessage,
  });

  final String query;
  final SearchResultCategory selectedCategory;
  final List<String> recentSearches;
  final List<SearchResultItem> results;
  final bool isLoading;
  final String? errorMessage;

  List<String> get topSearches => const <String>[];
  bool get hasQuery => query.trim().isNotEmpty;
  List<SearchResultItem> get matchedResults => results;

  List<SearchResultItem> get visibleResults {
    switch (selectedCategory) {
      case SearchResultCategory.all:
        return matchedResults;
      case SearchResultCategory.users:
        return results
            .where((item) => item.type == SearchResultType.user)
            .toList(growable: false);
      case SearchResultCategory.rooms:
        return results
            .where((item) => item.type == SearchResultType.room)
            .toList(growable: false);
      case SearchResultCategory.vibes:
        return results
            .where((item) => item.type == SearchResultType.vibe)
            .toList(growable: false);
    }
  }

  int countForCategory(SearchResultCategory category) {
    switch (category) {
      case SearchResultCategory.all:
        return results.length;
      case SearchResultCategory.users:
        return results.where((item) => item.type == SearchResultType.user).length;
      case SearchResultCategory.rooms:
        return results.where((item) => item.type == SearchResultType.room).length;
      case SearchResultCategory.vibes:
        return results.where((item) => item.type == SearchResultType.vibe).length;
    }
  }

  VibeSearchState copyWith({
    String? query,
    SearchResultCategory? selectedCategory,
    List<String>? recentSearches,
    List<SearchResultItem>? results,
    bool? isLoading,
    Object? errorMessage = _searchUnset,
  }) {
    return VibeSearchState(
      query: query ?? this.query,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      recentSearches:
          List<String>.unmodifiable(recentSearches ?? this.recentSearches),
      results: List<SearchResultItem>.unmodifiable(results ?? this.results),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: identical(errorMessage, _searchUnset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class VibeSearchController extends AutoDisposeNotifier<VibeSearchState> {
  late final SearchApiService _searchApiService;
  Timer? _debounceTimer;
  int _requestSerial = 0;

  @override
  VibeSearchState build() {
    _searchApiService = SearchApiService();
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _searchApiService.close();
    });
    return const VibeSearchState();
  }

  void setQuery(String value) {
    _debounceTimer?.cancel();
    if (value.trim().isEmpty) {
      state = state.copyWith(
        query: value,
        selectedCategory: SearchResultCategory.all,
        results: const <SearchResultItem>[],
        isLoading: false,
        errorMessage: null,
      );
      return;
    }
    state = state.copyWith(
      query: value,
      selectedCategory: SearchResultCategory.all,
      isLoading: true,
      errorMessage: null,
    );
    _debounceTimer = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_performSearch(value)),
    );
  }

  void clearQuery() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      query: '',
      selectedCategory: SearchResultCategory.all,
      results: const <SearchResultItem>[],
      isLoading: false,
      errorMessage: null,
    );
  }

  void selectCategory(SearchResultCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  void submitSearch(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    _rememberSearch(clean);
    _debounceTimer?.cancel();
    unawaited(_performSearch(clean));
  }

  Future<void> retry() => _performSearch(state.query);

  Future<void> _performSearch(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final serial = ++_requestSerial;
    state = state.copyWith(
      query: value,
      isLoading: true,
      errorMessage: null,
    );

    try {
      final results = await _searchApiService.search(clean);
      if (serial != _requestSerial) return;
      state = state.copyWith(
        results: results,
        isLoading: false,
        errorMessage: null,
      );
    } catch (error) {
      if (serial != _requestSerial) return;
      state = state.copyWith(
        results: const <SearchResultItem>[],
        isLoading: false,
        errorMessage: error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _rememberSearch(String clean) {
    final recent = List<String>.of(state.recentSearches)
      ..removeWhere((item) => item.toLowerCase() == clean.toLowerCase())
      ..insert(0, clean);
    if (recent.length > 8) recent.removeLast();
    state = state.copyWith(recentSearches: recent);
  }

  void removeRecentSearch(String value) {
    state = state.copyWith(
      recentSearches:
          state.recentSearches.where((item) => item != value).toList(),
    );
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: const <String>[]);
  }
}

final vibeSearchControllerProvider =
    NotifierProvider.autoDispose<VibeSearchController, VibeSearchState>(
      VibeSearchController.new,
    );
