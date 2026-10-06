import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/vm_navigator.dart';
import '../../../core/network/vm_failure.dart';
import '../../../core/presentation/vm_async_state.dart';
import '../../../core/ui/vm_motion.dart';
import '../../vibes/data/vibes_api_service.dart';
import '../../vibes/presentation/pages/vibe_detail_backend_page.dart';
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
  bool _openingResult = false;

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

  Future<void> _openResult(SearchResultItem item) async {
    if (_openingResult) return;
    final searchState = ref.read(vibeSearchControllerProvider);
    ref
        .read(vibeSearchControllerProvider.notifier)
        .submitSearch(searchState.query);
    FocusManager.instance.primaryFocus?.unfocus();

    switch (item.type) {
      case SearchResultType.user:
        _openUserResult(item);
        return;
      case SearchResultType.room:
        _openRoomResult(item);
        return;
      case SearchResultType.vibe:
        await _openVibeResult(item);
        return;
    }
  }

  Future<void> _openVibeResult(SearchResultItem item) async {
    final vibeId = item.vibeId?.trim();
    if (vibeId == null || vibeId.isEmpty) {
      _toast('This Vibe is unavailable. Refresh search and try again.');
      return;
    }

    setState(() => _openingResult = true);
    try {
      final vibe = await const VibesApiService().getVibe(vibeId);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        VmMotion.pageRoute<void>(
          settings: RouteSettings(name: 'search-vibe:$vibeId'),
          page: VibeDetailBackendPage(vibe: vibe),
        ),
      );
    } catch (error) {
      if (mounted) {
        _toast(
          VmFailurePresentation.messageFor(
            error,
            contentLabel: 'Vibe',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _openingResult = false);
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
            if (_openingResult)
              const LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF12C7B7),
                backgroundColor: Color(0xFFECE2D8),
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
      return const VmLoadingState(message: 'Searching…');
    }

    final error = state.errorMessage;
    if (error != null) {
      return VmFailureState(
        message: error,
        contentLabel: 'search results',
        onRetry: () => controller.retry(),
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
