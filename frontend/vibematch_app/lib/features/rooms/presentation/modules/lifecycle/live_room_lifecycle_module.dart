import 'package:flutter/material.dart';

import '../../live_room_restore_state.dart';
import '../live_room_controller_bundle.dart';
import '../live_room_leave_actions_module.dart';
import '../seats/live_room_seats_module.dart';
import '../../widgets/live_room_minimized_overlay_service.dart';
import '../../widgets/room_seats.dart';

class LiveRoomLifecycleModule {
  const LiveRoomLifecycleModule._();

  static bool isSecretPresenceRoom(LiveRoomControllerBundle bundle) {
    final mode = bundle.config.modeTitle.toLowerCase();
    final privacy = bundle.privacyMode.toString().toLowerCase();
    return mode.contains('secret') || privacy.contains('secret');
  }

  static void startRoomPresence(LiveRoomControllerBundle bundle) {
    bundle.presenceController.start(
      roomPublicId: bundle.roomId,
      roomName: bundle.roomName,
      roomMode: bundle.config.modeTitle,
      isSecret: isSecretPresenceRoom(bundle),
    );
  }

  static void syncPresenceRoomDetails(LiveRoomControllerBundle bundle) {
    bundle.presenceController.updateRoom(
      roomPublicId: bundle.roomId,
      roomName: bundle.roomName,
      roomMode: bundle.config.modeTitle,
      isSecret: isSecretPresenceRoom(bundle),
    );
  }

  static void onRoomStateChanged(LiveRoomControllerBundle bundle) {
    syncPresenceRoomDetails(bundle);
    final syncedLayout = bundle.roomStateController.seatLayoutId;
    if (syncedLayout.trim().isNotEmpty &&
        syncedLayout != bundle.seatController.layoutId) {
      bundle.seatController.changeLayout(syncedLayout);
      LiveRoomSeatsModule.autoOccupySeatOneForHostOrAdmin(bundle);
    }
    if (bundle.mounted) bundle.setRoomState(() {});
  }

  static void handleRoomPop({
    required LiveRoomControllerBundle bundle,
    required bool didPop,
  }) {
    if (bundle.navigationController.shouldBlockBackAction(
      allowRoomPop: bundle.allowRoomPop,
      didPop: didPop,
    )) {
      dismissRoomSeatActionPill();
      openLeaveSheet(bundle);
    }
  }

  static Future<void>? openLeaveSheet(LiveRoomControllerBundle bundle) {
    final restoreState = buildRestoreState(bundle);
    final roomName = bundle.roomName;
    final roomId = bundle.roomId;
    final onlineCount = bundle.safeOnlineCount;

    return LiveRoomLeaveActionsModule.openLeaveSheet(
      context: bundle.context,
      navigationController: bundle.navigationController,
      roomStateController: bundle.roomStateController,
      roomName: roomName,
      roomId: roomId,
      language: bundle.config.language,
      modeTitle: bundle.config.modeTitle,
      onlineCount: onlineCount,
      restoreState: restoreState,
      dismissSeatActionPill: dismissRoomSeatActionPill,
      clearFocus: () => clearFocus(bundle),
      restoreMinimizedRoom: () => restoreMinimizedRoom(bundle),
      mountedGetter: () => bundle.mounted,
    );
  }

  static void leaveRoomFromSheet({
    required LiveRoomControllerBundle bundle,
    required BuildContext sheetContext,
  }) {
    LiveRoomLeaveActionsModule.leaveRoomFromSheet(
      context: bundle.context,
      sheetContext: sheetContext,
      navigationController: bundle.navigationController,
      roomStateController: bundle.roomStateController,
      mountedGetter: () => bundle.mounted,
    );
  }

  static void restoreMinimizedRoom(LiveRoomControllerBundle bundle) {
    if (!bundle.mounted) return;
    dismissRoomSeatActionPill();
    clearFocus(bundle);
    bundle.roomStateController.setBubbleOffset(
      LiveRoomMinimizedOverlayService.instance.offset,
    );
    bundle.roomStateController.setMinimized(false);
  }

  static void clearFocus(LiveRoomControllerBundle bundle) {
    bundle.messageFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static LiveRoomRestoreState buildRestoreState(
    LiveRoomControllerBundle bundle,
  ) {
    return LiveRoomRestoreState(
      roomState: bundle.roomStateController.snapshotForRestore(),
      messageState: bundle.roomMessageController.snapshotForRestore(),
      seatState: bundle.seatController.snapshotForRestore(),
      messageDraft: bundle.messageController.text,
    );
  }
}
