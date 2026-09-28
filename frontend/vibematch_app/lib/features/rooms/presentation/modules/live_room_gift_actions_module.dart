import 'dart:async';

import 'package:flutter/material.dart';

import '../../../gifts/presentation/lucky_gift_rankings_sheet.dart';
import '../../data/gift_catalog_api_service.dart';
import '../../data/lucky_packet_realtime_service.dart';
import '../controllers/live_room_gift_controller.dart';
import '../controllers/live_room_sheet_controller.dart';
import '../live_room_models.dart';
import '../widgets/gift_modules/lucky_packet_setup_sheet.dart';
import '../widgets/live_room_gift_panel_sheet.dart';
import '../widgets/room_theme.dart';

class LiveRoomGiftActionsModule {
  const LiveRoomGiftActionsModule._();

  static const GiftCatalogApiService _catalogApi = GiftCatalogApiService();

  static Future<void> openGiftPanel({
    required BuildContext context,
    required LiveRoomGiftController giftController,
    required LuckyPacketRealtimeService luckyPacketService,
    required List<SeatUser> roomUsers,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    giftController.ensureDefaultReceiver(roomUsers);

    GiftCatalogSnapshot catalog;
    try {
      catalog = await _catalogApi.fetchActiveCatalog();
    } catch (error) {
      if (context.mounted) {
        RoomToast.show(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
      return;
    }

    if (!context.mounted) return;
    if (catalog.isEmpty) {
      RoomToast.show(context, 'No active gifts available from backend catalog');
      return;
    }

    final selectedGift = _selectedGiftFromCatalog(
      current: giftController.selectedGift,
      catalog: catalog,
    );
    if (selectedGift != null &&
        selectedGift.id != giftController.selectedGift?.id) {
      giftController.selectGift(selectedGift);
    }
    final selectedCategoryKey =
        selectedGift?.categoryKey ?? catalog.categories.first.key;

    return LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LiveRoomGiftPanelSheet(
        categories: catalog.categories,
        gifts: catalog.gifts,
        users: roomUsers,
        selectedCategoryKey: selectedCategoryKey,
        selectedGift: selectedGift,
        selectedReceiverIds: giftController.selectedReceiverIds,
        selectedCombo: giftController.selectedCombo,
        coinBalance: giftController.coinBalance,
        onCategoryChanged: (_) {},
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
                luckyPacketService: luckyPacketService,
                roomUsers: roomUsers,
              );
            });
            return;
          }
          giftController.sendGift(roomUsers);
        },
        onRecharge: () =>
            RoomToast.show(context, 'Wallet / coin recharge opened'),
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

  static GiftItem? _selectedGiftFromCatalog({
    required GiftItem? current,
    required GiftCatalogSnapshot catalog,
  }) {
    if (current != null) {
      for (final gift in catalog.gifts) {
        if (gift.id == current.id) return gift;
      }
    }
    final firstCategoryKey = catalog.categories.first.key;
    for (final gift in catalog.gifts) {
      if ((gift.categoryKey ?? gift.category.label.toLowerCase()) ==
          firstCategoryKey) {
        return gift;
      }
    }
    return catalog.gifts.isEmpty ? null : catalog.gifts.first;
  }

  static Future<void> _openLuckyPacketSetup({
    required BuildContext context,
    required LiveRoomGiftController giftController,
    required LuckyPacketRealtimeService luckyPacketService,
    required List<SeatUser> roomUsers,
  }) {
    return LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => LuckyPacketSetupSheet(
        coinBalance: giftController.coinBalance,
        onSend: (coinAmount, peopleCount, message) {
          unawaited(() async {
            try {
              final result = await luckyPacketService.create(
                coinAmount: coinAmount,
                winnerCount: peopleCount,
                message: message,
              );
              final nextBalance = result.senderCoinBalance;
              if (nextBalance != null) {
                giftController.coinBalance = nextBalance;
                giftController.onChanged();
              }
              giftController.onToast('Lucky Packet sent');
              if (context.mounted) Navigator.pop(context);
            } catch (error) {
              giftController.onToast(
                error.toString().replaceFirst('Exception: ', ''),
              );
              unawaited(giftController.refreshCoinBalance());
            }
          }());
        },
      ),
    );
  }
}
