import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../application/search_controller.dart';
import '../models/search_result_item.dart';
import '../models/search_result_type.dart';
import 'widgets/search_category_tabs.dart';
import 'widgets/search_discover_view.dart';
import 'widgets/search_header.dart';
import 'widgets/search_results_view.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _useSearchText(String text) {
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    final controller = ref.read(vibeSearchControllerProvider.notifier);
    controller.setQuery(text);
    controller.submitSearch(text);
  }

  void _clearSearch() {
    _textController.clear();
    ref.read(vibeSearchControllerProvider.notifier).clearQuery();
    _focusNode.requestFocus();
  }

  void _openResult(SearchResultItem item) {
    final searchState = ref.read(vibeSearchControllerProvider);
    ref.read(vibeSearchControllerProvider.notifier).submitSearch(searchState.query);
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
    final search = ref.watch(vibeSearchControllerProvider);
    final controller = ref.read(vibeSearchControllerProvider.notifier);
    final hasQuery = search.hasQuery;

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
              onChanged: controller.setQuery,
              onSubmitted: controller.submitSearch,
            ),
            if (hasQuery)
              SearchCategoryTabs(
                selectedCategory: search.selectedCategory,
                countForCategory: search.countForCategory,
                onCategoryChanged: controller.selectCategory,
              ),
            Expanded(
              child: hasQuery
                  ? _ProductionSearchResults(
                      state: search,
                      controller: controller,
                      onResultTap: _openResult,
                    )
                  : SearchDiscoverView(
                      recentSearches: search.recentSearches,
                      topSearches: search.topSearches,
                      onRecentTap: _useSearchText,
                      onTopSearchTap: _useSearchText,
                      onRemoveRecentTap: controller.removeRecentSearch,
                      onClearRecentTap: controller.clearRecentSearches,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductionSearchResults extends StatelessWidget {
  const _ProductionSearchResults({
    required this.state,
    required this.controller,
    required this.onResultTap,
  });

  final VibeSearchState state;
  final VibeSearchController controller;
  final ValueChanged<SearchResultItem> onResultTap;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF251538)));
    }

    final error = state.errorMessage;
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
      query: state.query,
      results: state.visibleResults,
      selectedCategory: state.selectedCategory,
      onResultTap: onResultTap,
    );
  }
}
