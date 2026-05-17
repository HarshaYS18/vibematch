import 'package:flutter/material.dart';

import '../../../data/gift_catalog_api_service.dart';
import '../../live_room_models.dart';
import 'compact_gift_card.dart';

class GiftGalleryPager extends StatelessWidget {
  const GiftGalleryPager({
    super.key,
    required this.controller,
    required this.categories,
    required this.gifts,
    required this.selectedCategoryKey,
    required this.selectedGift,
    required this.onCategoryChanged,
    required this.onGiftSelected,
  });

  final PageController controller;
  final List<GiftCatalogCategory> categories;
  final List<GiftItem> gifts;
  final String selectedCategoryKey;
  final GiftItem? selectedGift;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<GiftItem> onGiftSelected;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      itemCount: categories.length,
      onPageChanged: (index) {
        final category = categories[index];
        if (category.key != selectedCategoryKey) onCategoryChanged(category.key);
      },
      itemBuilder: (context, index) {
        final category = categories[index];
        final filtered = _orderedGiftsForCategory(category.key);

        if (filtered.isEmpty) {
          return const Center(
            child: Text(
              'No active gifts in this category',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
        }

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

  List<GiftItem> _orderedGiftsForCategory(String categoryKey) {
    final filtered = gifts
        .where((gift) => (gift.categoryKey ?? gift.category.label.toLowerCase()) == categoryKey)
        .toList();
    if (categoryKey != 'lucky') return filtered;

    filtered.sort((left, right) {
      if (left.id == 'lucky_packet') return 1;
      if (right.id == 'lucky_packet') return -1;
      return 0;
    });
    return filtered;
  }
}
