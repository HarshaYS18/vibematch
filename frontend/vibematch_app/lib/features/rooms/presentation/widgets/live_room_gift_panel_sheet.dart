import 'package:flutter/material.dart';

import '../controllers/live_room_gift_panel_state_controller.dart';
import '../live_room_models.dart';
import 'gift_panel/live_room_gift_category_pager.dart';
import 'gift_panel/live_room_gift_panel_footer.dart';
import 'gift_panel/live_room_gift_panel_header.dart';
import 'gift_panel/live_room_gift_receiver_strip.dart';
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
  late final LiveRoomGiftPanelStateController _stateController;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _stateController = LiveRoomGiftPanelStateController(
      gifts: widget.gifts,
      initialCategory: widget.selectedCategory,
      initialGift: widget.selectedGift,
      initialReceiverIds: widget.selectedReceiverIds,
      initialCombo: widget.selectedCombo,
    );
    _pageController = _stateController.createPageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  void _selectCategory(GiftCategory category, {bool animatePage = true}) {
    if (_stateController.categoryNotifier.value == category) return;

    final gift = _stateController.selectCategory(category);
    final combo = _stateController.comboNotifier.value;

    widget.onCategoryChanged(category);
    if (gift != null) widget.onGiftSelected(gift);
    widget.onComboChanged(combo);

    if (animatePage && _pageController.hasClients) {
      _pageController.animateToPage(
        GiftCategory.values.indexOf(category),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _selectGift(GiftItem gift) {
    final combo = _stateController.selectGift(gift);
    widget.onGiftSelected(gift);
    widget.onComboChanged(combo);
  }

  void _toggleReceiver(String id) {
    widget.onReceiverToggle(id);
    _stateController.toggleReceiver(id: id, users: widget.users);
  }

  void _changeCombo(int combo) {
    final safeCombo = _stateController.setCombo(combo);
    widget.onComboChanged(safeCombo);
  }

  @override
  Widget build(BuildContext context) {
    final panelHeight = MediaQuery.sizeOf(context).height * 0.38;

    return SizedBox(
      height: panelHeight,
      child: RepaintBoundary(
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
              LiveRoomGiftPanelHeader(
                selectedCategoryListenable: _stateController.categoryNotifier,
                onCategoryChanged: _selectCategory,
                onStoreTap: () => RoomToast.show(context, 'Store / inventory opened'),
              ),
              const SizedBox(height: 7),
              LiveRoomGiftReceiverStrip(
                users: widget.users,
                selectedReceiverIdsListenable: _stateController.receiversNotifier,
                onReceiverToggle: _toggleReceiver,
              ),
              const SizedBox(height: 7),
              Expanded(
                child: LiveRoomGiftCategoryPager(
                  pageController: _pageController,
                  allGifts: _stateController.allGifts,
                  selectedCategoryListenable: _stateController.categoryNotifier,
                  selectedGiftListenable: _stateController.giftNotifier,
                  onPageChanged: (category) => _selectCategory(category, animatePage: false),
                  onGiftSelected: _selectGift,
                ),
              ),
              const SizedBox(height: 7),
              LiveRoomGiftPanelFooter(
                selectedCategoryListenable: _stateController.categoryNotifier,
                selectedGiftListenable: _stateController.giftNotifier,
                comboListenable: _stateController.comboNotifier,
                coinBalance: widget.coinBalance,
                comboOptionsFor: _stateController.comboOptionsFor,
                onComboChanged: _changeCombo,
                onSend: widget.onSend,
                onRecharge: widget.onRecharge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
