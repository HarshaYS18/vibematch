import 'package:flutter/material.dart';

import '../../../data/gift_catalog_api_service.dart';
import '../room_theme.dart';

class GiftCategoryStrip extends StatelessWidget {
  const GiftCategoryStrip({
    super.key,
    required this.categories,
    required this.selectedCategoryKey,
    required this.onChanged,
  });

  final List<GiftCatalogCategory> categories;
  final String selectedCategoryKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.key == selectedCategoryKey;
          return GestureDetector(
            onTap: () => onChanged(category.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? RoomColors.gold
                    : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.26)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Text(
                category.label,
                style: TextStyle(
                  color: selected ? RoomColors.deep : Colors.white,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
