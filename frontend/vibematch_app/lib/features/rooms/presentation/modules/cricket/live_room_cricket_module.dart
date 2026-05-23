import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/live_room_media_signaling_service.dart';
import '../../widgets/cricket_room_backgrounds.dart';
import '../../widgets/room_theme.dart';
import '../chat/live_room_chat_module.dart';
import '../cricket_room_mode_registry.dart';
import '../cricket_room_mode_signal.dart';
import '../cricket_stumps_flow_module.dart';
import '../lifecycle/live_room_lifecycle_module.dart';
import '../live_room_controller_bundle.dart';

class LiveRoomCricketModule {
  const LiveRoomCricketModule._();

  static void capturePreCricketRoomState(LiveRoomControllerBundle bundle) {
    if (CricketRoomModeSignal.isActive(bundle.roomId)) return;
    bundle.preCricketLayoutId ??= bundle.seatController.layoutId;
    if (bundle.preCricketBackgroundTheme == null &&
        !isCricketRoomBackground(bundle.selectedBackgroundTheme)) {
      bundle.preCricketBackgroundTheme = bundle.selectedBackgroundTheme;
    }
  }

  static RoomBackgroundTheme normalBackgroundAfterCricket(
    LiveRoomControllerBundle bundle,
  ) {
    final savedBackground = bundle.preCricketBackgroundTheme;
    if (savedBackground == null || isCricketRoomBackground(savedBackground)) {
      return defaultRoomBackgroundTheme;
    }
    return savedBackground;
  }

  static void startNewMatch(LiveRoomControllerBundle bundle) {
    if (!CricketRoomModeSignal.isActive(bundle.roomId)) return;
    LiveRoomLifecycleModule.clearFocus(bundle);
    CricketStumpsFlowModule.open(
      context: bundle.context,
      roomId: bundle.roomId,
      roomName: bundle.roomName,
      canManage: true,
      previousBackground: normalBackgroundAfterCricket(bundle),
      onBackgroundChanged:
          bundle.roomStateController.setSelectedBackgroundTheme,
      onSystemMessage: (message) =>
          LiveRoomChatModule.insertSystemMessage(bundle, message),
    );
  }

  static void endMatch(LiveRoomControllerBundle bundle) {
    final restoreLayout =
        bundle.preCricketLayoutId ?? bundle.roomStateController.seatLayoutId;
    final restoreBackground = normalBackgroundAfterCricket(bundle);

    LiveRoomMediaSignalingService.instance.endCricketMode(bundle.roomId);
    CricketRoomModeRegistry.disposeRoom(bundle.roomId);

    bundle.seatController.changeLayout(restoreLayout);
    bundle.roomStateController.setSeatLayoutId(restoreLayout);
    bundle.roomStateController.setSelectedBackgroundTheme(restoreBackground);
    LiveRoomMediaSignalingService.instance.setRoomBackgroundTheme(
      restoreBackground.id,
    );

    bundle.preCricketLayoutId = null;
    bundle.preCricketBackgroundTheme = null;

    RoomToast.show(bundle.context, 'Cricket Mode ended');
    LiveRoomChatModule.insertSystemMessage(
      bundle,
      'Cricket Mode ended by ${bundle.currentUser.name}. Chat room restored.',
    );
  }

  static void openFromSettings({
    required LiveRoomControllerBundle bundle,
    required BuildContext sheetContext,
  }) {
    Navigator.pop(sheetContext);
    capturePreCricketRoomState(bundle);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!bundle.mounted) return;
      CricketStumpsFlowModule.open(
        context: bundle.context,
        roomId: bundle.roomId,
        roomName: bundle.roomName,
        canManage: bundle.viewerCanManageRoom,
        previousBackground: bundle.selectedBackgroundTheme,
        onBackgroundChanged:
            bundle.roomStateController.setSelectedBackgroundTheme,
        onSystemMessage: (message) =>
            LiveRoomChatModule.insertSystemMessage(bundle, message),
      );
    });
  }
}
