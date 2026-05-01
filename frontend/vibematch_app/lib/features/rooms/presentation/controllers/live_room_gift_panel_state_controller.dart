import 'package:flutter/material.dart';

import '../live_room_models.dart';
import '../widgets/room_gifts.dart';

class LiveRoomGiftPanelStateController {
  LiveRoomGiftPanelStateController({
    required List<GiftItem> gifts,
    required GiftCategory initialCategory,
    required GiftItem? initialGift,
    required Set<String> initialReceiverIds,
    required int initialCombo,
  })  : allGifts = GiftPanel.withMockExtras(gifts),
        categoryNotifier = ValueNotifier<GiftCategory>(initialCategory),
        giftNotifier = ValueNotifier<GiftItem?>(initialGift),
        comboNotifier = ValueNotifier<int>(initialCombo),
        receiversNotifier = ValueNotifier<Set<String>>(Set<String>.from(initialReceiverIds)) {
    giftNotifier.value ??= firstGiftForCategory(initialCategory);
  }

  final List<GiftItem> allGifts;
  final ValueNotifier<GiftCategory> categoryNotifier;
  final ValueNotifier<GiftItem?> giftNotifier;
  final ValueNotifier<int> comboNotifier;
  final ValueNotifier<Set<String>> receiversNotifier;

  GiftItem? firstGiftForCategory(GiftCategory category) {
    for (final gift in allGifts) {
      if (gift.category == category) return gift;
    }
    return null;
  }

  int defaultComboFor(GiftCategory category) {
    return category == GiftCategory.lucky ? 9 : 1;
  }

  List<int> comboOptionsFor(GiftCategory category) {
    return category == GiftCategory.lucky ? GiftPanel.luckyCombos : GiftPanel.combos;
  }

  GiftItem? selectCategory(GiftCategory category) {
    if (categoryNotifier.value == category) return giftNotifier.value;

    final gift = firstGiftForCategory(category);
    final combo = defaultComboFor(category);

    categoryNotifier.value = category;
    giftNotifier.value = gift;
    comboNotifier.value = combo;

    return gift;
  }

  int selectGift(GiftItem gift) {
    final combo = gift.isVideoGift ? 1 : defaultComboFor(gift.category);

    giftNotifier.value = gift;
    categoryNotifier.value = gift.category;
    comboNotifier.value = combo;

    return combo;
  }

  int setCombo(int combo) {
    final selectedGift = giftNotifier.value;
    final safeCombo = selectedGift?.isVideoGift ?? false ? 1 : combo;
    comboNotifier.value = safeCombo;
    return safeCombo;
  }

  Set<String> toggleReceiver({
    required String id,
    required List<SeatUser> users,
  }) {
    final current = Set<String>.from(receiversNotifier.value);

    if (id == '__all__') {
      final allSelected = users.isNotEmpty && current.length == users.length;
      current
        ..clear()
        ..addAll(allSelected ? const <String>[] : users.map((user) => user.id));
    } else if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }

    receiversNotifier.value = current;
    return current;
  }

  PageController createPageController() {
    return PageController(
      initialPage: GiftCategory.values.indexOf(categoryNotifier.value),
    );
  }

  void dispose() {
    categoryNotifier.dispose();
    giftNotifier.dispose();
    comboNotifier.dispose();
    receiversNotifier.dispose();
  }
}
