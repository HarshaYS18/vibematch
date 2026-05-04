import 'package:flutter/material.dart';

import '../live_room_page.dart';
import 'live_room_route_args.dart';

class LiveRoomRoutes {
  const LiveRoomRoutes._();

  static MaterialPageRoute<void> liveRoom(LiveRoomRouteViewArgs args) {
    return MaterialPageRoute<void>(
      builder: (_) => LiveRoomPage(
        roomName: args.roomName,
        roomId: args.roomId,
        language: args.language,
        modeTitle: args.modeTitle,
        onlineCount: args.onlineCount,
      ),
    );
  }
}
