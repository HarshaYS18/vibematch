import 'package:flutter/material.dart';

import 'live_room_restore_state.dart';
import 'modules/layout/live_room_layout_module.dart';
import 'modules/live_room_controller_bundle.dart';
import 'modules/live_room_controller_scope.dart';
import 'widgets/room_theme.dart';

class LiveRoomPage extends StatelessWidget {
  const LiveRoomPage({
    super.key,
    this.roomName = 'Live Room',
    this.roomId = 'VM000000',
    this.language = 'Telugu',
    this.modeTitle = 'Open',
    this.onlineCount = 1,
    this.initialBackgroundTheme,
    this.restoreState,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;
  final RoomBackgroundTheme? initialBackgroundTheme;
  final LiveRoomRestoreState? restoreState;

  @override
  Widget build(BuildContext context) {
    return LiveRoomControllerScope(
      config: LiveRoomControllerConfig(
        roomName: roomName,
        roomId: roomId,
        language: language,
        modeTitle: modeTitle,
        onlineCount: onlineCount,
        initialBackgroundTheme: initialBackgroundTheme,
        restoreState: restoreState,
      ),
      builder: (context, bundle) => LiveRoomLayoutModule(bundle: bundle),
    );
  }
}
