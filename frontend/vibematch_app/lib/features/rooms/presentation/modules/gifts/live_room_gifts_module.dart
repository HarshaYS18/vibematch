import '../live_room_controller_bundle.dart';
import '../live_room_gift_actions_module.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../../controllers/live_room_gift_controller.dart';
import '../../widgets/room_theme.dart';

/// Creates room-scoped gift controllers from the canonical controller bundle.
///
/// Durable room identity is injected into the gift controller; this module does
/// not consult transport/global active-room state.
class LiveRoomGiftsModule {
  const LiveRoomGiftsModule._();

  static LiveRoomGiftController controllerFor(LiveRoomControllerBundle bundle) {
    return bundle.giftControllerInstance ??= LiveRoomGiftController(
      currentUser: bundle.currentUser,
      roomPublicId: bundle.roomId,
      onChanged: bundle.notifyGiftChanged,
      onFinalGiftMessage: (entry) {
        if (!bundle.mounted) return;
        bundle.roomMessageController.insertEntry(entry);
      },
      onToast: (message) {
        if (!bundle.mounted) return;
        RoomToast.show(bundle.context, message);
      },
    );
  }

  static void openGiftPanel(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    final controller = controllerFor(bundle);
    controller.refreshCoinBalance();
    LiveRoomGiftActionsModule.openGiftPanel(
      context: bundle.context,
      giftController: controller,
      luckyPacketService: bundle.luckyPacketRealtimeService,
      roomUsers: bundle.roomUsers,
    );
  }
}
