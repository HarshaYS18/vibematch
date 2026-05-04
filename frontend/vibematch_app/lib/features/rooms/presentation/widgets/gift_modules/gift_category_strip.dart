import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';

class GiftCategoryStrip extends StatelessWidget {
  const GiftCategoryStrip({super.key, required this.selectedCategory, required this.onChanged});

  final GiftCategory selectedCategory;
  final ValueChanged<GiftCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: GiftCategory.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final category = GiftCategory.values[index];
          final selected = category == selectedCategory;
          return GestureDetector(
            onTap: () => onChanged(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? RoomColors.gold : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.26) : Colors.white.withValues(alpha: 0.06)),
              ),
              child: Text(
                category.label,
                style: TextStyle(color: selected ? RoomColors.deep : Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
              ),
            ),
          );
        },
      ),
    );
  }
}
