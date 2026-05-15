import 'package:flutter/material.dart';

import '../../../gifts/presentation/lucky_gift_rankings_sheet.dart';
import '../controllers/live_room_gift_controller.dart';
import '../controllers/live_room_sheet_controller.dart';
import '../live_room_models.dart';
import '../widgets/gift_modules/lucky_packet_setup_sheet.dart';
import '../widgets/live_room_gift_panel_sheet.dart';
import '../widgets/room_theme.dart';

class LiveRoomGiftActionsModule {
  const LiveRoomGiftActionsModule._();

  static Future<void> openGiftPanel({
    required BuildContext context,
    required LiveRoomGiftController giftController,
    required List<SeatUser> roomUsers,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    giftController.ensureDefaultReceiver(roomUsers);

    return LiveRoomSheetController.showTransparentSheet<void>(
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
          if (giftController.selectedGiftIsLuckyPacket) {
            Future<void>.delayed(const Duration(milliseconds: 90), () {
              if (!context.mounted) return;
              _openLuckyPacketSetup(
                context: context,
                giftController: giftController,
                roomUsers: roomUsers,
              );
            });
            return;
          }
          giftController.sendGift(roomUsers);
        },
        onRecharge: () => RoomToast.show(context, 'Wallet / coin recharge opened'),
        onLuckyRankingsTap: () {
          Navigator.pop(context);
          Future<void>.delayed(const Duration(milliseconds: 90), () {
            if (!context.mounted) return;
            LuckyGiftRankingsSheet.show(context);
          });
        },
      ),
    );
  }

  static Future<void> _openLuckyPacketSetup({
    required BuildContext context,
    required LiveRoomGiftController giftController,
    required List<SeatUser> roomUsers,
  }) {
    return LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LuckyPacketSetupSheet(
        coinBalance: giftController.coinBalance,
        onSend: (coinAmount, peopleCount, message) {
          final sent = giftController.sendLuckyPacket(
            coinAmount: coinAmount,
            winnerCount: peopleCount,
            message: message,
            roomUsers: roomUsers,
          );
          if (sent) Navigator.pop(context);
        },
      ),
    );
  }
}