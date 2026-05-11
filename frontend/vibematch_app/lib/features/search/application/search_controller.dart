import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/search_api_service.dart';
import '../models/search_result_item.dart';
import '../models/search_result_type.dart';

class VibeSearchController extends ChangeNotifier {
  VibeSearchController({SearchApiService? searchApiService}) : _searchApiService = searchApiService ?? SearchApiService();

  final SearchApiService _searchApiService;
  final List<String> _recentSearches = <String>[];
  final List<SearchResultItem> _results = <SearchResultItem>[];
  Timer? _debounceTimer;

  String _query = '';
  SearchResultCategory _selectedCategory = SearchResultCategory.all;
  bool _isLoading = false;
  String? _errorMessage;
  int _requestSerial = 0;

  String get query => _query;
  SearchResultCategory get selectedCategory => _selectedCategory;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<String> get topSearches => const <String>[];
  bool get hasQuery => _query.trim().isNotEmpty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<SearchResultItem> get matchedResults => List.unmodifiable(_results);

  List<SearchResultItem> get visibleResults {
    switch (_selectedCategory) {
      case SearchResultCategory.all:
        return matchedResults;
      case SearchResultCategory.users:
        return _results.where((item) => item.type == SearchResultType.user).toList();
      case SearchResultCategory.rooms:
        return _results.where((item) => item.type == SearchResultType.room).toList();
      case SearchResultCategory.vibes:
        return _results.where((item) => item.type == SearchResultType.vibe).toList();
    }
  }

  int countForCategory(SearchResultCategory category) {
    switch (category) {
      case SearchResultCategory.all:
        return _results.length;
      case SearchResultCategory.users:
        return _results.where((item) => item.type == SearchResultType.user).length;
      case SearchResultCategory.rooms:
        return _results.where((item) => item.type == SearchResultType.room).length;
      case SearchResultCategory.vibes:
        return _results.where((item) => item.type == SearchResultType.vibe).length;
    }
  }

  void setQuery(String value) {
    _query = value;
    _selectedCategory = SearchResultCategory.all;
    _errorMessage = null;
    _debounceTimer?.cancel();
    if (!hasQuery) {
      _results.clear();
      _isLoading = false;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () => unawaited(_performSearch(_query)));
  }

  void clearQuery() {
    _debounceTimer?.cancel();
    _query = '';
    _selectedCategory = SearchResultCategory.all;
    _results.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  void selectCategory(SearchResultCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void submitSearch(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;
    _rememberSearch(clean);
    _debounceTimer?.cancel();
    unawaited(_performSearch(clean));
  }

  Future<void> retry() => _performSearch(_query);

  Future<void> _performSearch(String value) async {
    final clean = value.trim();
    if (clean.isEmpty) return;
    final serial = ++_requestSerial;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await _searchApiService.search(clean);
      if (serial != _requestSerial) return;
      _results
        ..clear()
        ..addAll(results);
      _isLoading = false;
    } catch (error) {
      if (serial != _requestSerial) return;
      _results.clear();
      _isLoading = false;
      _errorMessage = error.toString().replaceFirst('Exception: ', '');
    }
    notifyListeners();
  }

  void _rememberSearch(String clean) {
    _recentSearches.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    _recentSearches.insert(0, clean);
    if (_recentSearches.length > 8) _recentSearches.removeLast();
    notifyListeners();
  }

  void removeRecentSearch(String value) {
    _recentSearches.remove(value);
    notifyListeners();
  }

  void clearRecentSearches() {
    _recentSearches.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchApiService.close();
    super.dispose();
  }
}
