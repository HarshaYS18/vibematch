import 'package:flutter/material.dart';

import '../../live_room_models.dart';
import '../room_theme.dart';
import 'gift_bottom_action_bar.dart';
import 'gift_category_strip.dart';
import 'gift_gallery_pager.dart';
import 'gift_mock_extras.dart';
import 'gift_panel_constants.dart';
import 'gift_panel_header.dart';
import 'gift_targets_row.dart';

class GiftPanelModular extends StatefulWidget {
  const GiftPanelModular({
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
    this.onLuckyRankingsTap,
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
  final VoidCallback? onLuckyRankingsTap;

  static List<GiftItem> withMockExtras(List<GiftItem> gifts) =>
      GiftMockExtras.mergeWith(gifts);

  @override
  State<GiftPanelModular> createState() => _GiftPanelModularState();
}

class _GiftPanelModularState extends State<GiftPanelModular> {
  late final PageController _categoryPageController;

  int _pageIndexFor(GiftCategory category) {
    final index = GiftCategoryStrip.visibleCategories.indexOf(category);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    _categoryPageController = PageController(
      initialPage: _pageIndexFor(widget.selectedCategory),
    );
  }

  @override
  void didUpdateWidget(covariant GiftPanelModular oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory &&
        _categoryPageController.hasClients) {
      _categoryPageController.animateToPage(
        _pageIndexFor(widget.selectedCategory),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _categoryPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allGifts = GiftPanelModular.withMockExtras(widget.gifts);
    final comboOptions = widget.selectedCategory == GiftCategory.lucky
        ? GiftPanelConstants.luckyCombos
        : GiftPanelConstants.combos;
    final isLuckyPacket = widget.selectedGift?.id == 'lucky_packet';
    final comboValue = isLuckyPacket
        ? 1
        : (comboOptions.contains(widget.selectedCombo)
              ? widget.selectedCombo
              : comboOptions.first);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.414,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          10,
          7,
          10,
          MediaQuery.paddingOf(context).bottom + 8,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF12101D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(width: 42),
            const SizedBox(height: 6),
            GiftPanelHeader(
              selectedCategory: widget.selectedCategory,
              onCategoryChanged: (category) {
                widget.onCategoryChanged(category);
                _categoryPageController.animateToPage(
                  _pageIndexFor(category),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                );
              },
              onStoreTap: () =>
                  RoomToast.show(context, 'Store / inventory opened'),
              onLuckyRankingsTap: widget.onLuckyRankingsTap,
            ),
            const SizedBox(height: 7),
            GiftTargetsRow(
              users: widget.users,
              selectedUserIds: widget.selectedReceiverIds,
              onAllTap: () => widget.onReceiverToggle('__all__'),
              onUserTap: widget.onReceiverToggle,
            ),
            const SizedBox(height: 7),
            Expanded(
              child: GiftGalleryPager(
                controller: _categoryPageController,
                gifts: allGifts,
                selectedCategory: widget.selectedCategory,
                selectedGift: widget.selectedGift,
                onCategoryChanged: widget.onCategoryChanged,
                onGiftSelected: widget.onGiftSelected,
              ),
            ),
            const SizedBox(height: 7),
            GiftBottomActionBar(
              comboValue: comboValue,
              comboOptions: isLuckyPacket ? const [1] : comboOptions,
              coinBalance: widget.coinBalance,
              comboEnabled: !isLuckyPacket,
              onSend: widget.onSend,
              onComboChanged: widget.onComboChanged,
              onRecharge: widget.onRecharge,
            ),
          ],
        ),
      ),
    );
  }
}
