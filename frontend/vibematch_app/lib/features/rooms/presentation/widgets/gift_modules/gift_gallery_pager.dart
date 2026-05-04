import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import 'compact_gift_card.dart';

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
    return PageView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      itemCount: GiftCategory.values.length,
      onPageChanged: (index) {
        final category = GiftCategory.values[index];
        if (category != selectedCategory) onCategoryChanged(category);
      },
      itemBuilder: (context, index) {
        final category = GiftCategory.values[index];
        final filtered = gifts.where((gift) => gift.category == category).toList();

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
}
