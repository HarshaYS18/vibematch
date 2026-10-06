import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/live_room_sheet_controller.dart';
import '../../widgets/pk/room_pk_challenge_sheet.dart';
import '../../widgets/room_theme.dart';
import '../live_room_controller_bundle.dart';

class LiveRoomPkModule {
  const LiveRoomPkModule._();

  static void openFromSettings({
    required LiveRoomControllerBundle bundle,
    required BuildContext sheetContext,
  }) {
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!bundle.mounted) return;
      open(bundle);
    });
  }

  static void open(LiveRoomControllerBundle bundle) {
    if (bundle.cricketModeController.active &&
        !bundle.pkController.pending &&
        !bundle.pkController.active) {
      RoomToast.show(
        bundle.context,
        'End Cricket Mode before starting Room PK',
      );
      return;
    }

    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (_) => RoomPkChallengeSheet(
        controller: bundle.pkController,
        canManage: bundle.viewerCanManageRoom,
        cricketModeActive: bundle.cricketModeController.active,
      ),
    );
  }
}
