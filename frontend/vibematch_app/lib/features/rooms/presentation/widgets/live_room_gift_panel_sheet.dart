import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_gifts.dart';

class LiveRoomGiftPanelSheet extends StatelessWidget {
  const LiveRoomGiftPanelSheet({
    super.key,
    required this.gifts,
    required this.users,
    required this.selectedCategory,
    required this.selectedGift,
    required this.selectedReceiverIds,
    required this.selectedCombo,
    required this.coinBalance,
    required this.onCategoryChanged,
    required this.onGiftSelected,
    required this.onReceiverToggle,
    required this.onComboChanged,
    required this.onSend,
    required this.onRecharge,
  });

  final List<GiftItem> gifts;
  final List<SeatUser> users;
  final GiftCategory selectedCategory;
  final GiftItem? selectedGift;
  final Set<String> selectedReceiverIds;
  final int selectedCombo;
  final int coinBalance;

  final ValueChanged<GiftCategory> onCategoryChanged;
  final ValueChanged<GiftItem> onGiftSelected;
  final ValueChanged<String> onReceiverToggle;
  final ValueChanged<int> onComboChanged;
  final VoidCallback onSend;
  final VoidCallback onRecharge;

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return GiftPanel(
          gifts: gifts,
          users: users,
          selectedCategory: selectedCategory,
          selectedGift: selectedGift,
          selectedReceiverIds: selectedReceiverIds,
          selectedCombo: selectedCombo,
          coinBalance: coinBalance,
          onCategoryChanged: (category) {
            onCategoryChanged(category);
            setSheetState(() {});
          },
          onGiftSelected: (gift) {
            onGiftSelected(gift);
            setSheetState(() {});
          },
          onReceiverToggle: (id) {
            onReceiverToggle(id);
            setSheetState(() {});
          },
          onComboChanged: (combo) {
            onComboChanged(combo);
            setSheetState(() {});
          },
          onSend: onSend,
          onRecharge: onRecharge,
        );
      },
    );
  }
}