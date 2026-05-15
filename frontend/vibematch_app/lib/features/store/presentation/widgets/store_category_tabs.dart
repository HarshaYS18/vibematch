import 'package:flutter/material.dart';

import '../../models/store_models.dart';

class StoreCategoryTabs extends StatelessWidget {
  const StoreCategoryTabs({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<String> categories;
  final String? selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 42,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return ChoiceChip(
            selected: selected,
            label: Text(storeCategoryLabel(category)),
            onSelected: (_) => onSelected(category),
            selectedColor: const Color(0x3312C7B7),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? const Color(0xFF12C7B7) : const Color(0xFFEDE3D7),
            ),
            labelStyle: TextStyle(
              color: selected ? const Color(0xFF251538) : const Color(0xFF7B6A86),
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }
}
