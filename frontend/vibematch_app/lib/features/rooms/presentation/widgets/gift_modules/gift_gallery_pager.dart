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
    final filtered = _orderedGiftsForCategory(selectedCategoryKey);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No gifts yet',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return GridView.builder(
      key: PageStorageKey<String>('gift-grid-$selectedCategoryKey'),
      padding: const EdgeInsets.fromLTRB(2, 1, 2, 12),
      primary: false,
      shrinkWrap: false,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      itemCount: filtered.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
        childAspectRatio: 0.78,
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
}
