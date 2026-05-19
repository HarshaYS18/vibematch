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
        if (category.key != selectedCategoryKey)
          onCategoryChanged(category.key);
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

        final pages = _giftPages(filtered);
        return PageView.builder(
          physics: const BouncingScrollPhysics(),
          itemCount: pages.length,
          itemBuilder: (context, pageIndex) {
            final pageItems = pages[pageIndex];
            return GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pageItems.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.02,
              ),
              itemBuilder: (context, giftIndex) {
                final gift = pageItems[giftIndex];
                return CompactGiftCard(
                  gift: gift,
                  selected: selectedGift?.id == gift.id,
                  onTap: () => onGiftSelected(gift),
                );
              },
            );
          },
        );
      },
    );
  }

  List<GiftItem> _orderedGiftsForCategory(String categoryKey) {
    final filtered = gifts
        .where(
          (gift) =>
              (gift.categoryKey ?? gift.category.label.toLowerCase()) ==
              categoryKey,
        )
        .toList();
    if (categoryKey != 'lucky') return filtered;

    filtered.sort((left, right) {
      if (left.id == 'lucky_packet') return 1;
      if (right.id == 'lucky_packet') return -1;
      return 0;
    });
    return filtered;
  }

  List<List<GiftItem>> _giftPages(List<GiftItem> source) {
    final pages = <List<GiftItem>>[];
    for (var index = 0; index < source.length; index += 6) {
      final end = index + 6 > source.length ? source.length : index + 6;
      pages.add(source.sublist(index, end));
    }
    return pages.isEmpty ? const <List<GiftItem>>[] : pages;
  }
}
