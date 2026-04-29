import 'package:flutter/material.dart';

import '../live_room_models.dart';
import 'room_gifts.dart';
import 'room_theme.dart';

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

  int _defaultComboFor(GiftCategory category) {
    return category == GiftCategory.lucky ? 9 : 1;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GiftPanel(
          gifts: widget.gifts,
          users: widget.users,
          selectedCategory: _selectedCategory,
          selectedGift: _selectedGift,
          selectedReceiverIds: widget.selectedReceiverIds,
          selectedCombo: _selectedGift?.isVideoGift ?? false ? 1 : _selectedCombo,
          coinBalance: widget.coinBalance,
          onCategoryChanged: (category) {
            widget.onCategoryChanged(category);
            setState(() {
              _selectedCategory = category;
              _selectedGift = _firstGiftForCategory(category) ?? _selectedGift;
              _selectedCombo = _defaultComboFor(category);
              if (_selectedGift != null) widget.onGiftSelected(_selectedGift!);
              widget.onComboChanged(_selectedCombo);
            });
          },
          onGiftSelected: (gift) {
            widget.onGiftSelected(gift);
            setState(() {
              _selectedGift = gift;
              _selectedCategory = gift.category;
              _selectedCombo = gift.isVideoGift ? 1 : _defaultComboFor(gift.category);
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
        ),
        if (_selectedGift != null)
          Positioned(
            left: 12,
            right: 12,
            top: 92,
            child: _SelectedGiftPreview(gift: _selectedGift!),
          ),
      ],
    );
  }
}

class _SelectedGiftPreview extends StatelessWidget {
  const _SelectedGiftPreview({required this.gift});

  final GiftItem gift;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 238),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: gift.colors.first.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GiftVisual(
                icon: gift.icon,
                colors: gift.colors,
                assetPath: gift.assetPath,
                size: 42,
                padding: 2,
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          gift.isVideoGift ? Icons.play_circle_fill_rounded : Icons.auto_awesome_rounded,
                          color: gift.isVideoGift ? RoomColors.coral : RoomColors.gold,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          gift.isVideoGift ? 'Video effect • x1 only' : '${gift.coins} coins',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: gift.isVideoGift ? RoomColors.coral : RoomColors.gold,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
