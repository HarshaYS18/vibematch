import 'package:flutter/material.dart';

import '../controllers/live_room_navigation_controller.dart';
import '../controllers/live_room_sheet_controller.dart';
import '../controllers/live_room_state_controller.dart';
import '../live_room_restore_state.dart';
import '../widgets/live_room_leave_sheet.dart';
import '../widgets/live_room_minimized_overlay_service.dart';

class LiveRoomLeaveActionsModule {
  const LiveRoomLeaveActionsModule._();

  static Future<void>? openLeaveSheet({
    required BuildContext context,
    required LiveRoomNavigationController navigationController,
    required LiveRoomStateController roomStateController,
    required String roomName,
    required String roomId,
    required String language,
    required String modeTitle,
    required int onlineCount,
    required LiveRoomRestoreState restoreState,
    required VoidCallback dismissSeatActionPill,
    required VoidCallback clearFocus,
    required VoidCallback restoreMinimizedRoom,
    required bool Function() mountedGetter,
  }) {
    dismissSeatActionPill();

    if (!navigationController.canOpenLeaveSheet(
      leaveSheetOpen: roomStateController.leaveSheetOpen,
      exitingRoom: roomStateController.exitingRoom,
    )) {
      return null;
    }

    roomStateController.setLeaveSheetOpen(true);
    clearFocus();

    return LiveRoomSheetController.showTransparentSheet<void>(
      context: context,
      builder: (sheetContext) => LiveRoomLeaveSheet(
        onStay: () {
          dismissSeatActionPill();
          _stayAndMinimize(
            sheetContext: sheetContext,
            roomStateController: roomStateController,
            restoreMinimizedRoom: restoreMinimizedRoom,
            mountedGetter: mountedGetter,
          );
        },
        onLeave: () {
          dismissSeatActionPill();
          leaveRoomFromSheet(
            context: context,
            sheetContext: sheetContext,
            navigationController: navigationController,
            roomStateController: roomStateController,
            mountedGetter: mountedGetter,
          );
        },
      ),
    ).whenComplete(() {
      if (mountedGetter()) roomStateController.setLeaveSheetOpen(false);
    });
  }

  static void leaveRoomFromSheet({
    required BuildContext context,
    required BuildContext sheetContext,
    required LiveRoomNavigationController navigationController,
    required LiveRoomStateController roomStateController,
    required bool Function() mountedGetter,
  }) {
    if (!navigationController.canExitRoom(
      exitingRoom: roomStateController.exitingRoom,
    )) {
      if (roomStateController.exitingRoom) {
        _popRoomRouteAfterLeave(
          roomNavigator: Navigator.of(context),
          roomStateController: roomStateController,
          mountedGetter: mountedGetter,
        );
      }
      return;
    }

    final roomNavigator = Navigator.of(context);

    roomStateController.setExitingRoom(true);

    // Production rule:
    // Explicit Leave Room is different from minimize/network reconnect.
    // A real leave must release the current seat first so re-entry comes back
    // as audience unless the user explicitly takes a seat again.
    LiveRoomMinimizedOverlayService.hide();
    Navigator.pop(sheetContext);

    _popRoomRouteAfterLeave(
      roomNavigator: roomNavigator,
      roomStateController: roomStateController,
      mountedGetter: mountedGetter,
    );
  }

  static void _popRoomRouteAfterLeave({
    required NavigatorState roomNavigator,
    required LiveRoomStateController roomStateController,
    required bool Function() mountedGetter,
  }) {
    if (!mountedGetter()) return;
    roomStateController.setAllowRoomPop(true);

    void tryPop(int attempt) {
      if (!mountedGetter()) return;
      if (roomNavigator.canPop()) {
        roomNavigator.pop();
        return;
      }

      if (attempt < 3) {
        Future<void>.delayed(
          const Duration(milliseconds: 90),
          () => tryPop(attempt + 1),
        );
        return;
      }

      roomStateController.setExitingRoom(false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => tryPop(0));
  }

  static void _stayAndMinimize({
    required BuildContext sheetContext,
    required LiveRoomStateController roomStateController,
    required VoidCallback restoreMinimizedRoom,
    required bool Function() mountedGetter,
  }) {
    LiveRoomMinimizedOverlayService.show(onRestore: restoreMinimizedRoom);
    Navigator.pop(sheetContext);
    if (!mountedGetter()) return;

    // Keep the existing LiveRoomPage mounted instead of popping/recreating it.
    // This preserves WebSocket/media subscriptions, seat state, cricket score,
    // gift timers, presence heartbeat, and realtime user updates while minimized.
    roomStateController.setAllowRoomPop(false);
    roomStateController.setMinimized(true);
  }
}
