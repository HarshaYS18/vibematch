import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../controllers/live_room_navigation_controller.dart';
import '../controllers/live_room_sheet_controller.dart';
import '../controllers/live_room_state_controller.dart';
import '../live_room_presence_shell_page.dart';
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
            context: context,
            sheetContext: sheetContext,
            roomStateController: roomStateController,
            roomName: roomName,
            roomId: roomId,
            language: language,
            modeTitle: modeTitle,
            onlineCount: onlineCount,
            restoreState: restoreState,
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
    LiveRoomMediaSignalingService.instance.leaveSeat();
    unawaited(_leaveMediaRoomBestEffort());
    Navigator.pop(sheetContext);

    _popRoomRouteAfterLeave(
      roomNavigator: roomNavigator,
      roomStateController: roomStateController,
      mountedGetter: mountedGetter,
    );
  }

  static Future<void> _leaveMediaRoomBestEffort() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await LiveRoomMediaSignalingService.instance.leaveRoom().timeout(
        const Duration(seconds: 4),
      );
    } catch (_) {
      // Leaving the visible room route must not be blocked by socket cleanup.
    }
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
    required BuildContext context,
    required BuildContext sheetContext,
    required LiveRoomStateController roomStateController,
    required String roomName,
    required String roomId,
    required String language,
    required String modeTitle,
    required int onlineCount,
    required LiveRoomRestoreState restoreState,
    required bool Function() mountedGetter,
  }) {
    final roomNavigator = Navigator.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    LiveRoomMinimizedOverlayService.show(
      context: rootNavigator.context,
      onRestore: () {
        rootNavigator.push(
          MaterialPageRoute(
            builder: (_) => LiveRoomPresenceShellPage(
              roomName: roomName,
              roomId: roomId,
              language: language,
              modeTitle: modeTitle,
              initialOnlineCount: onlineCount,
              restoreState: restoreState,
            ),
          ),
        );
      },
    );

    Navigator.pop(sheetContext);
    if (!mountedGetter()) return;

    roomStateController.setAllowRoomPop(true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mountedGetter()) return;
      if (roomNavigator.canPop()) {
        roomNavigator.pop();
      } else {
        roomStateController.setMinimized(true);
      }
    });
  }
}

