import 'package:flutter/foundation.dart';

import '../data/search_mock_data.dart';
import '../models/search_result_item.dart';
import '../models/search_result_type.dart';

class VibeSearchController extends ChangeNotifier {
  VibeSearchController()
      : _recentSearches = List<String>.from(SearchMockData.recentSearches);

  String _query = '';
  SearchResultCategory _selectedCategory = SearchResultCategory.all;
  final List<String> _recentSearches;

  String get query => _query;
  SearchResultCategory get selectedCategory => _selectedCategory;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  List<String> get topSearches => SearchMockData.topSearches;
  bool get hasQuery => _query.trim().isNotEmpty;

  List<SearchResultItem> get matchedResults {
    if (!hasQuery) return const [];
    return SearchMockData.results.where((item) => item.matches(_query)).toList();
  }

  List<SearchResultItem> get visibleResults {
    final results = matchedResults;

    switch (_selectedCategory) {
      case SearchResultCategory.all:
        return results;
      case SearchResultCategory.users:
        return results.where((item) => item.type == SearchResultType.user).toList();
      case SearchResultCategory.rooms:
        return results.where((item) => item.type == SearchResultType.room).toList();
      case SearchResultCategory.vibes:
        return results.where((item) => item.type == SearchResultType.vibe).toList();
    }
  }

  int countForCategory(SearchResultCategory category) {
    switch (category) {
      case SearchResultCategory.all:
        return matchedResults.length;
      case SearchResultCategory.users:
        return matchedResults.where((item) => item.type == SearchResultType.user).length;
      case SearchResultCategory.rooms:
        return matchedResults.where((item) => item.type == SearchResultType.room).length;
      case SearchResultCategory.vibes:
        return matchedResults.where((item) => item.type == SearchResultType.vibe).length;
    }
  }

  void setQuery(String value) {
    _query = value;
    _selectedCategory = SearchResultCategory.all;
    notifyListeners();
  }

  void clearQuery() {
    _query = '';
    _selectedCategory = SearchResultCategory.all;
    notifyListeners();
  }

  void selectCategory(SearchResultCategory category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void submitSearch(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return;

    _recentSearches.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    _recentSearches.insert(0, clean);

    if (_recentSearches.length > 8) {
      _recentSearches.removeLast();
    }

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
}
