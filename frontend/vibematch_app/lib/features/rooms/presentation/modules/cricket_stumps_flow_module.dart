import 'package:flutter/material.dart';

import '../widgets/room_theme.dart';
import 'cricket_room_mode_signal.dart';
import 'cricket_stumps_flow_safe_module.dart';

/// Public entry point for the Cricket match setup flow.
///
/// Setup results are emitted through injected callbacks to the owning room
/// controller. This module retains no match state after the sheet closes.
class CricketStumpsFlowModule {
  const CricketStumpsFlowModule._();

  static Future<void> open({
    required BuildContext context,
    required String roomId,
    required String roomName,
    required bool canManage,
    required RoomBackgroundTheme previousBackground,
    required ValueChanged<RoomBackgroundTheme> onBackgroundChanged,
    required ValueChanged<CricketQuickMatchSetup> onMatchStarted,
    ValueChanged<String>? onSystemMessage,
  }) {
    return CricketStumpsFlowSafeModule.open(
      context: context,
      roomId: roomId,
      roomName: roomName,
      canManage: canManage,
      previousBackground: previousBackground,
      onBackgroundChanged: onBackgroundChanged,
      onMatchStarted: onMatchStarted,
      onSystemMessage: onSystemMessage,
    );
  }
}
