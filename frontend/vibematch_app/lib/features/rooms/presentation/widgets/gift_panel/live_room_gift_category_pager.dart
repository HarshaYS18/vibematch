import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_gifts.dart';

class LiveRoomGiftCategoryPager extends StatelessWidget {
  const LiveRoomGiftCategoryPager({
    super.key,
    required this.pageController,
    required this.allGifts,
    required this.selectedCategoryListenable,
    required this.selectedGiftListenable,
    required this.onPageChanged,
    required this.onGiftSelected,
  });

  final PageController pageController;
  final List<GiftItem> allGifts;
  final ValueListenable<GiftCategory> selectedCategoryListenable;
  final ValueListenable<GiftItem?> selectedGiftListenable;
  final ValueChanged<GiftCategory> onPageChanged;
  final ValueChanged<GiftItem> onGiftSelected;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<GiftItem?>(
        valueListenable: selectedGiftListenable,
        builder: (context, selectedGift, _) {
          return PageView.builder(
            controller: pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: GiftCategory.values.length,
            onPageChanged: (index) => onPageChanged(GiftCategory.values[index]),
            itemBuilder: (context, index) {
              final category = GiftCategory.values[index];
              final filtered = allGifts
                  .where((gift) => gift.category == category)
                  .toList(growable: false);
              return GridView.builder(
                key: PageStorageKey<String>('gift-grid-${category.name}'),
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.95,
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
        },
      ),
    );
  }
}
