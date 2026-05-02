import 'package:flutter/material.dart';

import '../live_room_models.dart';
import '../widgets/live_room_emoji_sheet.dart';
import '../widgets/live_room_games_sheet.dart';
import '../widgets/live_room_gift_panel_sheet.dart';
import '../widgets/live_room_users_sheet.dart';
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

  void openGamesSheet({
    required BuildContext context,
    required VoidCallback onCrystalHuntTap,
    required VoidCallback onLudoTap,
    required VoidCallback onCarromTap,
    required VoidCallback onPkTap,
  }) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomGamesSheet(
        onCrystalHuntTap: onCrystalHuntTap,
        onLudoTap: onLudoTap,
        onCarromTap: onCarromTap,
        onPkTap: onPkTap,
      ),
    );
  }

  void openEmojiSheet({
    required BuildContext context,
    required ValueChanged<String> onEmojiTap,
  }) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (_) => LiveRoomEmojiSheet(onEmojiTap: onEmojiTap),
    );
  }

  void openRoomUsersSheet({
    required BuildContext context,
    required List<SeatUser> users,
    required ValueChanged<SeatUser> onUserTap,
  }) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LiveRoomUsersSheet(
        users: users,
        onUserTap: onUserTap,
      ),
    );
  }
}
