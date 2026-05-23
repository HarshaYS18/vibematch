import '../live_room_controller_bundle.dart';
import '../live_room_gift_actions_module.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../../controllers/live_room_gift_controller.dart';
import '../../widgets/room_theme.dart';

class LiveRoomGiftsModule {
  const LiveRoomGiftsModule._();

  static LiveRoomGiftController controllerFor(LiveRoomControllerBundle bundle) {
    return bundle.giftControllerInstance ??= LiveRoomGiftController(
      currentUser: bundle.currentUser,
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

  static void bindLuckyPacketBusIfReady(LiveRoomControllerBundle bundle) {
    final controller = bundle.giftControllerInstance;
    if (controller == null) return;
    controller.ensureDefaultReceiver(bundle.roomUsers);
    LuckyPacketRoomBus.bind(
      controller: controller,
      roomUsers: bundle.allRoomUsers,
    );
  }

  static void openGiftPanel(LiveRoomControllerBundle bundle) {
    LiveRoomLifecycleModule.clearFocus(bundle);
    LiveRoomGiftActionsModule.openGiftPanel(
      context: bundle.context,
      giftController: controllerFor(bundle),
      roomUsers: bundle.roomUsers,
    );
  }
}
