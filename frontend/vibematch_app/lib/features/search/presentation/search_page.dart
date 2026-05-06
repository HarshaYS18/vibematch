import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/navigation/vm_navigator.dart';
import '../../vibes/data/vibes_mock_data.dart';
import '../../vibes/models/vibe_models.dart';
import '../../vibes/presentation/pages/vibe_detail_page_modular.dart';
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
    final vibe = _resolveVibe(item);

    Navigator.push<void>(
      context,
      MaterialPageRoute(
        settings: RouteSettings(
          name: VmRoutes.vibeDetail,
          arguments: vibe,
        ),
        builder: (_) => VibeDetailPageModular(vibe: vibe),
      ),
    );
  }

  VibeItem _resolveVibe(SearchResultItem item) {
    final byId = VibesMockData.vibes.where((vibe) => vibe.id == item.vibeId);
    if (byId.isNotEmpty) return byId.first;

    final byTitle = VibesMockData.vibes.where((vibe) {
      return vibe.caption.toLowerCase().contains(item.title.toLowerCase()) ||
          item.title.toLowerCase().contains(vibe.caption.toLowerCase());
    });
    if (byTitle.isNotEmpty) return byTitle.first;

    return VibeItem(
      id: item.vibeId ?? 'search_vibe_result',
      authorName: item.vibeAuthorName ?? item.title,
      authorId: item.vibeAuthorId ?? item.userId ?? 'unknown',
      avatarText: (item.vibeAuthorName ?? item.title).trim().isEmpty
          ? 'V'
          : (item.vibeAuthorName ?? item.title).trim().characters.first.toUpperCase(),
      timeAgo: 'Now',
      mediaType: _inferMediaType(item),
      caption: item.title,
      tag: item.tag,
      likes: 0,
      comments: 0,
      shares: 0,
      views: 0,
      isFollowing: false,
      usesMentionAll: false,
      mentions: const [],
      colors: [item.color, const Color(0xFF251538)],
    );
  }

  VibeMediaType _inferMediaType(SearchResultItem item) {
    final text = '${item.title} ${item.subtitle} ${item.keywords.join(' ')}'.toLowerCase();
    if (text.contains('video')) return VibeMediaType.video;
    if (text.contains('text')) return VibeMediaType.text;
    return VibeMediaType.photo;
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
