import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/live_room_sheet_controller.dart';
import '../../widgets/room_contribution_rankings_sheet.dart';
import '../live_room_controller_bundle.dart';
import '../profile/live_room_profile_module.dart';

/// Opens rankings with the canonical room id from the mounted controller bundle.
class LiveRoomRankingsEntryModule {
  const LiveRoomRankingsEntryModule._();

  static void openRoomRankingsSheet(LiveRoomControllerBundle bundle) {
    LiveRoomSheetController.showTransparentSheet<void>(
      context: bundle.context,
      isScrollControlled: true,
      builder: (_) => RoomContributionRankingsSheet(
        roomName: bundle.roomName,
        roomPublicId: bundle.roomId,
        users: bundle.allRoomUsers,
        onUserTap: (user) {
          Navigator.pop(bundle.context);
          Future<void>.delayed(const Duration(milliseconds: 80), () {
            if (bundle.mounted) {
              LiveRoomProfileModule.openMiniProfileForUser(bundle, user);
            }
          });
        },
      ),
    );
  }
}
