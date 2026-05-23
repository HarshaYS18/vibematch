import 'package:flutter/material.dart';

import '../widgets/room_theme.dart';
import 'cricket_stumps_flow_safe_module.dart';

class CricketStumpsFlowModule {
  const CricketStumpsFlowModule._();

  static Future<void> open({
    required BuildContext context,
    required String roomId,
    required String roomName,
    required bool canManage,
    required RoomBackgroundTheme previousBackground,
    required ValueChanged<RoomBackgroundTheme> onBackgroundChanged,
    ValueChanged<String>? onSystemMessage,
  }) {
    return CricketStumpsFlowSafeModule.open(
      context: context,
      roomId: roomId,
      roomName: roomName,
      canManage: canManage,
      previousBackground: previousBackground,
      onBackgroundChanged: onBackgroundChanged,
      onSystemMessage: onSystemMessage,
    );
  }
}
