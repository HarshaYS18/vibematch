import 'package:flutter/material.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../application/search_controller.dart';
import '../models/search_result_item.dart';
import '../models/search_result_type.dart';
import 'widgets/search_category_tabs.dart';
import 'widgets/search_discover_view.dart';
import 'widgets/search_header.dart';
import 'widgets/search_results_view.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final VibeSearchController _searchController = VibeSearchController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) setState(() {});
  }

  void _useSearchText(String text) {
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    _searchController.setQuery(text);
    _searchController.submitSearch(text);
  }

  void _clearSearch() {
    _textController.clear();
    _searchController.clearQuery();
    _focusNode.requestFocus();
  }

  void _openResult(SearchResultItem item) {
    _searchController.submitSearch(_searchController.query);
    FocusManager.instance.primaryFocus?.unfocus();

    switch (item.type) {
      case SearchResultType.user:
        _openUserResult(item);
        return;
      case SearchResultType.room:
        _openRoomResult(item);
        return;
      case SearchResultType.vibe:
        _toast('Vibe search will appear after backend Vibe search endpoint is added.');
        return;
    }
  }

  void _openUserResult(SearchResultItem item) {
    VmNavigator.openPublicProfile(
      context,
      userId: item.userId ?? item.title,
      displayName: item.title,
      username: item.username,
    );
  }

  void _openRoomResult(SearchResultItem item) {
    VmNavigator.openLiveRoom(
      context,
      roomName: item.title,
      roomId: item.roomId ?? item.title,
      language: item.roomLanguage ?? 'All',
      modeTitle: item.roomModeTitle ?? 'Open',
      onlineCount: item.roomOnlineCount ?? 1,
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF251538),
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.hasQuery;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F1),
      body: SafeArea(
        child: Column(
          children: [
            SearchHeader(
              controller: _textController,
              focusNode: _focusNode,
              hasQuery: hasQuery,
              onBackTap: () => Navigator.pop(context),
              onClearTap: _clearSearch,
              onChanged: _searchController.setQuery,
              onSubmitted: _searchController.submitSearch,
            ),
            if (hasQuery)
              SearchCategoryTabs(
                selectedCategory: _searchController.selectedCategory,
                countForCategory: _searchController.countForCategory,
                onCategoryChanged: _searchController.selectCategory,
              ),
            Expanded(
              child: hasQuery
                  ? _ProductionSearchResults(
                      controller: _searchController,
                      onResultTap: _openResult,
                    )
                  : SearchDiscoverView(
                      recentSearches: _searchController.recentSearches,
                      topSearches: _searchController.topSearches,
                      onRecentTap: _useSearchText,
                      onTopSearchTap: _useSearchText,
                      onRemoveRecentTap: _searchController.removeRecentSearch,
                      onClearRecentTap: _searchController.clearRecentSearches,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductionSearchResults extends StatelessWidget {
  const _ProductionSearchResults({required this.controller, required this.onResultTap});

  final VibeSearchController controller;
  final ValueChanged<SearchResultItem> onResultTap;

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF251538)));
    }

    final error = controller.errorMessage;
    if (error != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE8C77C))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Color(0xFFC99A3B), size: 34),
              const SizedBox(height: 10),
              const Text('Search failed', style: TextStyle(color: Color(0xFF251538), fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7B6A86), fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              FilledButton(onPressed: () => controller.retry(), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return SearchResultsView(
      query: controller.query,
      results: controller.visibleResults,
      selectedCategory: controller.selectedCategory,
      onResultTap: onResultTap,
    );
  }
}
