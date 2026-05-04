import 'package:flutter/material.dart';

import 'room_rankings_models.dart';

class RoomRankingCategoryTabs extends StatelessWidget {
  const RoomRankingCategoryTabs({
    super.key,
    required this.selectedCategory,
    required this.onChanged,
  });

  final RoomRankingCategory selectedCategory;
  final ValueChanged<RoomRankingCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: RoomRankingCategory.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = RoomRankingCategory.values[index];
          final selected = category == selectedCategory;
          return _RankingCategoryChip(
            category: category,
            selected: selected,
            onTap: () => onChanged(category),
          );
        },
      ),
    );
  }
}

class _RankingCategoryChip extends StatelessWidget {
  const _RankingCategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final RoomRankingCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? Colors.white.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.08),
            border: Border.all(
              color: selected ? category.accentColor.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.14),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: category.accentColor.withValues(alpha: 0.20),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, color: selected ? category.accentColor : Colors.white.withValues(alpha: 0.74), size: 15),
              const SizedBox(width: 5),
              Text(
                category.label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white.withValues(alpha: 0.74),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
