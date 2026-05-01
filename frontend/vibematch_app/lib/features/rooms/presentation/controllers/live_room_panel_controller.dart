import 'package:flutter/material.dart';

import '../live_room_models.dart';
import '../widgets/live_room_gift_panel_sheet.dart';
import '../widgets/room_gifts.dart';
import '../widgets/room_seats.dart';
import 'live_room_gift_controller.dart';
import 'live_room_sheet_controller.dart';

class LiveRoomPanelController {
  const LiveRoomPanelController();

  void openGiftPanel({
    required BuildContext context,
    required LiveRoomGiftController giftController,
    required List<SeatUser> roomUsers,
    required VoidCallback onRecharge,
  }) {
    giftController.ensureDefaultReceiver(roomUsers);

    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LiveRoomGiftPanelSheet(
        gifts: mockGiftItems,
        users: roomUsers,
        selectedCategory: giftController.selectedCategory,
        selectedGift: giftController.selectedGift,
        selectedReceiverIds: giftController.selectedReceiverIds,
        selectedCombo: giftController.selectedCombo,
        coinBalance: giftController.coinBalance,
        onCategoryChanged: giftController.selectCategory,
        onGiftSelected: giftController.selectGift,
        onReceiverToggle: (id) => giftController.toggleReceiver(id, roomUsers),
        onComboChanged: giftController.setCombo,
        onSend: () {
          Navigator.pop(context);
          giftController.sendGift(roomUsers);
        },
        onRecharge: onRecharge,
      ),
    );
  }
}
