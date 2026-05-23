import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/live_room_sheet_controller.dart';
import '../../widgets/live_room_info_sheet.dart';
import '../live_room_controller_bundle.dart';

class LiveRoomWatchPartyEntryModule {
  const LiveRoomWatchPartyEntryModule._();

  static void openFromSettings({
    required LiveRoomControllerBundle bundle,
    required BuildContext sheetContext,
  }) {
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!bundle.mounted) return;
      LiveRoomSheetController.showTransparentSheet<void>(
        context: bundle.context,
        builder: (context) => const LiveRoomInfoSheet(
          title: 'Watch Party',
          body:
              'Watch Party settings will open here. YouTube link, play/pause/seek sync, and 10-seat watch layout will connect next.',
        ),
      );
    });
  }
}
