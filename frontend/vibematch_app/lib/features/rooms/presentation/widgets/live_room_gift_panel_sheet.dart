import 'package:flutter/material.dart';

import '../../data/gift_catalog_api_service.dart';
import '../live_room_models.dart';
import 'gift_modules/gift_panel_modular.dart';

class LiveRoomGiftPanelSheet extends StatefulWidget {
  const LiveRoomGiftPanelSheet({
    super.key,
    required this.categories,
    required this.gifts,
    required this.users,
    required this.selectedCategoryKey,
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
    this.onLuckyRankingsTap,
  });

  final List<GiftCatalogCategory> categories;
  final List<GiftItem> gifts;
  final List<SeatUser> users;
  final String selectedCategoryKey;
  final GiftItem? selectedGift;
  final Set<String> selectedReceiverIds;
  final int selectedCombo;
  final int coinBalance;

  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<GiftItem> onGiftSelected;
  final ValueChanged<String> onReceiverToggle;
  final ValueChanged<int> onComboChanged;
  final VoidCallback onSend;
  final VoidCallback onRecharge;
  final VoidCallback? onLuckyRankingsTap;

  @override
  State<LiveRoomGiftPanelSheet> createState() => _LiveRoomGiftPanelSheetState();
}

class _LiveRoomGiftPanelSheetState extends State<LiveRoomGiftPanelSheet> {
  late String _selectedCategoryKey;
  late GiftItem? _selectedGift;
  late int _selectedCombo;

  @override
  void initState() {
    super.initState();
    _selectedCategoryKey = widget.selectedCategoryKey;
    _selectedGift = widget.selectedGift;
    _selectedCombo = widget.selectedCombo;
  }

  GiftItem? _firstGiftForCategory(String categoryKey) {
    for (final gift in widget.gifts) {
      if ((gift.categoryKey ?? gift.category.label.toLowerCase()) == categoryKey) {
        return gift;
      }
    }
    return null;
  }

  int _defaultComboFor(String categoryKey) {
    return categoryKey == 'lucky' ? 9 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return GiftPanelModular(
      categories: widget.categories,
      gifts: widget.gifts,
      users: widget.users,
      selectedCategoryKey: _selectedCategoryKey,
      selectedGift: _selectedGift,
      selectedReceiverIds: widget.selectedReceiverIds,
      selectedCombo: _selectedGift?.isVideoGift ?? false ? 1 : _selectedCombo,
      coinBalance: widget.coinBalance,
      onCategoryChanged: (categoryKey) {
        widget.onCategoryChanged(categoryKey);
        setState(() {
          _selectedCategoryKey = categoryKey;
          _selectedGift = _firstGiftForCategory(categoryKey);
          _selectedCombo = _defaultComboFor(categoryKey);
          if (_selectedGift != null) widget.onGiftSelected(_selectedGift!);
          widget.onComboChanged(_selectedCombo);
        });
      },
      onGiftSelected: (gift) {
        widget.onGiftSelected(gift);
        setState(() {
          _selectedGift = gift;
          _selectedCategoryKey = gift.categoryKey ?? gift.category.label.toLowerCase();
          _selectedCombo = gift.isVideoGift ? 1 : _defaultComboFor(_selectedCategoryKey);
        });
        widget.onComboChanged(_selectedCombo);
      },
      onReceiverToggle: (id) {
        widget.onReceiverToggle(id);
        setState(() {});
      },
      onComboChanged: (combo) {
        if (_selectedGift?.isVideoGift ?? false) {
          widget.onComboChanged(1);
          setState(() => _selectedCombo = 1);
          return;
        }
        widget.onComboChanged(combo);
        setState(() => _selectedCombo = combo);
      },
      onSend: widget.onSend,
      onRecharge: widget.onRecharge,
      onLuckyRankingsTap: widget.onLuckyRankingsTap,
    );
  }
}
