import 'package:flutter/material.dart';

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

    return PageRouteBuilder<void>(
      opaque: false,
      maintainState: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) => LiveRoomPresenceShellPage(
        roomName: args.roomName,
        roomId: args.roomId,
        language: args.language,
        modeTitle: args.modeTitle,
        initialOnlineCount: args.onlineCount,
        currentUser: currentUser,
        lockPassword: args.lockPassword,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }
}
