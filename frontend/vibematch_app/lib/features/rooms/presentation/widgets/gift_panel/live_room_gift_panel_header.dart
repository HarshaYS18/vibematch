import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';

class LiveRoomGiftPanelHeader extends StatelessWidget {
  const LiveRoomGiftPanelHeader({
    super.key,
    required this.selectedCategoryListenable,
    required this.onCategoryChanged,
    required this.onStoreTap,
  });

  final ValueListenable<GiftCategory> selectedCategoryListenable;
  final ValueChanged<GiftCategory> onCategoryChanged;
  final VoidCallback onStoreTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.card_giftcard_rounded, color: RoomColors.gold, size: 18),
        const SizedBox(width: 6),
        const Text(
          'Gifts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ValueListenableBuilder<GiftCategory>(
            valueListenable: selectedCategoryListenable,
            builder: (context, category, _) {
              return _CategoryStripOptimized(
                selectedCategory: category,
                onChanged: onCategoryChanged,
              );
            },
          ),
        ),
        _TinyIconButton(icon: Icons.apps_rounded, onTap: onStoreTap),
      ],
    );
  }
}

class _CategoryStripOptimized extends StatelessWidget {
  const _CategoryStripOptimized({
    required this.selectedCategory,
    required this.onChanged,
  });

  final GiftCategory selectedCategory;
  final ValueChanged<GiftCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        height: 30,
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
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? RoomColors.gold : Colors.white.withValues(alpha: 0.08),
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
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Icon(icon, color: Colors.white, size: 17),
      ),
    );
  }
}
