import 'package:flutter/material.dart';

import '../../data/live_room_media_signaling_service.dart';
import '../live_room_page.dart';
import 'live_room_route_args.dart';

class LiveRoomRoutes {
  const LiveRoomRoutes._();

  static MaterialPageRoute<void> liveRoom(LiveRoomRouteViewArgs args) {
    final currentUser = args.currentUser;
    if (currentUser != null) {
      LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(currentUser);
    }

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
