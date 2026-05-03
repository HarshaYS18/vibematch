import 'package:flutter/material.dart';

import '../../models/search_result_type.dart';

class SearchCategoryTabs extends StatelessWidget {
  const SearchCategoryTabs({
    super.key,
    required this.selectedCategory,
    required this.countForCategory,
    required this.onCategoryChanged,
  });

  final SearchResultCategory selectedCategory;
  final int Function(SearchResultCategory category) countForCategory;
  final ValueChanged<SearchResultCategory> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      color: const Color(0xFFFAF7F1),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        scrollDirection: Axis.horizontal,
        itemCount: SearchResultCategory.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = SearchResultCategory.values[index];
          final selected = category == selectedCategory;
          final count = countForCategory(category);

          return InkWell(
            onTap: () => onCategoryChanged(category),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF251538) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? const Color(0xFF251538) : const Color(0xFFECE2D8),
                ),
              ),
              child: Center(
                child: Text(
                  '${category.label} $count',
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF7A6B86),
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
