import 'package:flutter/material.dart';

import '../../models/search_result_item.dart';
import '../../models/search_result_type.dart';

class SearchResultsView extends StatelessWidget {
  const SearchResultsView({
    super.key,
    required this.query,
    required this.results,
    required this.selectedCategory,
    required this.onResultTap,
  });

  final String query;
  final List<SearchResultItem> results;
  final SearchResultCategory selectedCategory;
  final ValueChanged<SearchResultItem> onResultTap;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _EmptySearchState(query: query, selectedCategory: selectedCategory);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = results[index];
        return _SearchResultTile(item: item, onTap: () => onResultTap(item));
      },
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.item, required this.onTap});

  final SearchResultItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFECE2D8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF251538).withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF251538),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7A6B86),
                        fontSize: 11.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.tag,
                  style: TextStyle(
                    color: item.color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query, required this.selectedCategory});

  final String query;
  final SearchResultCategory selectedCategory;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFECE2D8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: const Color(0xFF8C5CF6).withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.search_off_rounded, color: Color(0xFF8C5CF6), size: 32),
            ),
            const SizedBox(height: 13),
            Text(
              'No ${selectedCategory.label.toLowerCase()} found',
              style: const TextStyle(
                color: Color(0xFF251538),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nothing matched "$query". Try a user name, room name, room ID, language, or Vibe keyword.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7A6B86),
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
