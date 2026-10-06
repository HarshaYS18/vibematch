import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/live_room_sheet_controller.dart';
import '../../widgets/room_theme.dart';
import '../live_room_controller_bundle.dart';
import 'live_room_watch_party_router_sheet.dart';

class LiveRoomWatchPartyEntryModule {
  const LiveRoomWatchPartyEntryModule._();

  static void openFromSettings({
    required LiveRoomControllerBundle bundle,
    required BuildContext sheetContext,
  }) {
    if (bundle.pkController.pending || bundle.pkController.active) {
      RoomToast.show(bundle.context, 'End Room PK before starting Watch Party');
      return;
    }
    Navigator.pop(sheetContext);
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!bundle.mounted) return;
      _open(bundle);
    });
  }

  static void openFromRoom({
    required LiveRoomControllerBundle bundle,
  }) {
    if (!bundle.mounted) return;
    if (bundle.pkController.pending || bundle.pkController.active) {
      RoomToast.show(bundle.context, 'End Room PK before opening Watch Party');
      return;
    }
    _open(bundle);
  }

  static void _open(LiveRoomControllerBundle bundle) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (context) => LiveRoomWatchPartyRouterSheet(
        roomId: bundle.roomId,
        canManageRoom: bundle.viewerCanManageRoom,
        privacyMode: bundle.privacyMode,
      ),
    );
  }
}
