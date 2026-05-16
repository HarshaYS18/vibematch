import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import 'compact_gift_card.dart';
import 'gift_category_strip.dart';

class GiftGalleryPager extends StatelessWidget {
  const GiftGalleryPager({
    super.key,
    required this.controller,
    required this.gifts,
    required this.selectedCategory,
    required this.selectedGift,
    required this.onCategoryChanged,
    required this.onGiftSelected,
  });

  final PageController controller;
  final List<GiftItem> gifts;
  final GiftCategory selectedCategory;
  final GiftItem? selectedGift;
  final ValueChanged<GiftCategory> onCategoryChanged;
  final ValueChanged<GiftItem> onGiftSelected;

  @override
  Widget build(BuildContext context) {
    final categories = GiftCategoryStrip.visibleCategories;
    return PageView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      itemCount: categories.length,
      onPageChanged: (index) {
        final category = categories[index];
        if (category != selectedCategory) onCategoryChanged(category);
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        final filtered = _orderedGiftsForCategory(category);

        return GridView.builder(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          itemCount: filtered.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 0.92,
          ),
          itemBuilder: (context, giftIndex) {
            final gift = filtered[giftIndex];
            return CompactGiftCard(
              gift: gift,
              selected: selectedGift?.id == gift.id,
              onTap: () => onGiftSelected(gift),
            );
          },
        );
      },
    );
  }

  List<GiftItem> _orderedGiftsForCategory(GiftCategory category) {
    final filtered = gifts.where((gift) => gift.category == category).toList();
    if (category != GiftCategory.lucky) return filtered;

    filtered.sort((left, right) {
      if (left.id == 'lucky_packet') return 1;
      if (right.id == 'lucky_packet') return -1;
      return 0;
    });
    return filtered;
  }
}
