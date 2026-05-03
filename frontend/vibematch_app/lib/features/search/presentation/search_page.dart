import 'package:flutter/material.dart';

import '../application/search_controller.dart';
import '../models/search_result_item.dart';
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

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SearchResultActionSheet(item: item),
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

class _SearchResultActionSheet extends StatelessWidget {
  const _SearchResultActionSheet({required this.item});

  final SearchResultItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(14),
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        18 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE0D5CB),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(item.icon, color: item.color, size: 34),
          ),
          const SizedBox(height: 13),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF251538),
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF7A6B86),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SheetButton(
                  text: 'Close',
                  icon: Icons.close_rounded,
                  filled: false,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SheetButton(
                  text: 'Open',
                  icon: Icons.open_in_new_rounded,
                  filled: true,
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: const Color(0xFF251538),
                          content: Text(
                            '${item.title} detail route will connect next.',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.text,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  final String text;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF251538) : const Color(0xFFFAF7F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: filled ? const Color(0xFF251538) : const Color(0xFFECE2D8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: filled ? Colors.white : const Color(0xFF4A2A63),
              size: 19,
            ),
            const SizedBox(width: 7),
            Text(
              text,
              style: TextStyle(
                color: filled ? Colors.white : const Color(0xFF4A2A63),
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
