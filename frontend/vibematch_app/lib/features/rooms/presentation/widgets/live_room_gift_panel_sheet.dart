import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_gifts.dart';

class LiveRoomGiftPanelSheet extends StatefulWidget {
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
  State<LiveRoomGiftPanelSheet> createState() => _LiveRoomGiftPanelSheetState();
}

class _LiveRoomGiftPanelSheetState extends State<LiveRoomGiftPanelSheet> {
  late GiftCategory _selectedCategory;
  late GiftItem? _selectedGift;
  late int _selectedCombo;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedGift = widget.selectedGift;
    _selectedCombo = widget.selectedCombo;
  }

  GiftItem? _firstGiftForCategory(GiftCategory category) {
    for (final gift in GiftPanel.withMockExtras(widget.gifts)) {
      if (gift.category == category) return gift;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GiftPanel(
      gifts: widget.gifts,
      users: widget.users,
      selectedCategory: _selectedCategory,
      selectedGift: _selectedGift,
      selectedReceiverIds: widget.selectedReceiverIds,
      selectedCombo: _selectedCombo,
      coinBalance: widget.coinBalance,
      onCategoryChanged: (category) {
        widget.onCategoryChanged(category);
        setState(() {
          _selectedCategory = category;
          _selectedGift = _firstGiftForCategory(category) ?? _selectedGift;
          if (_selectedGift != null) widget.onGiftSelected(_selectedGift!);
          if (category == GiftCategory.lucky && _selectedCombo < 9) {
            _selectedCombo = 9;
            widget.onComboChanged(_selectedCombo);
          }
        });
      },
      onGiftSelected: (gift) {
        widget.onGiftSelected(gift);
        setState(() => _selectedGift = gift);
      },
      onReceiverToggle: (id) {
        widget.onReceiverToggle(id);
        setState(() {});
      },
      onComboChanged: (combo) {
        widget.onComboChanged(combo);
        setState(() => _selectedCombo = combo);
      },
      onSend: widget.onSend,
      onRecharge: widget.onRecharge,
    );
  }
}
