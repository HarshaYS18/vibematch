import 'package:flutter/material.dart';

import '../../../../core/ui/vm_motion.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../live_room_presence_shell_page.dart';
import 'live_room_route_args.dart';

class LiveRoomRoutes {
  const LiveRoomRoutes._();

  static PageRouteBuilder<void> liveRoom(LiveRoomRouteViewArgs args) {
    final currentUser = args.currentUser;
    if (currentUser != null) {
      LiveRoomMediaSignalingService.instance.setActiveLoggedInUser(currentUser);
    }

    return VmMotion.pageRoute<void>(
      settings: RouteSettings(arguments: args),
      beginOffset: const Offset(0.02, 0.018),
      page: LiveRoomPresenceShellPage(
        roomName: args.roomName,
        roomId: args.roomId,
        language: args.language,
        modeTitle: args.modeTitle,
        initialOnlineCount: args.onlineCount,
        currentUser: currentUser,
        lockPassword: args.lockPassword,
      ),
    );
  }
}
