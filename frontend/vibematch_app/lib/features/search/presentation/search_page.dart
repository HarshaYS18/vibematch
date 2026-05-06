import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/navigation/vm_navigator.dart';
import '../../../core/presentation/vm_skeleton_page.dart';
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
        _openVibeResult(item);
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

  void _openVibeResult(SearchResultItem item) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: VmRoutes.vibeDetail,
          arguments: item,
        ),
        builder: (_) => VmSkeletonPage(
          title: item.title,
          subtitle: 'Vibe by ${item.vibeAuthorName ?? item.subtitle}. This opens the exact Vibe result from search; backend will later hydrate the full post by vibeId ${item.vibeId ?? 'unknown'}.',
          icon: item.icon,
          highlights: [
            'Author: ${item.vibeAuthorName ?? 'Unknown'}',
            'Author ID: ${item.vibeAuthorId ?? 'Pending backend ID'}',
            'Vibe ID: ${item.vibeId ?? 'Pending backend ID'}',
            'Later this should render the real Vibe detail/comment page for this post.',
          ],
        ),
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
                  ? SearchResultsView(
                      query: _searchController.query,
                      results: _searchController.visibleResults,
                      selectedCategory: _searchController.selectedCategory,
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
