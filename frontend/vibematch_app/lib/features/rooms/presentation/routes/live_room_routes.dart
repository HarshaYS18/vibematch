import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
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

    final isHomeTopRightEntry =
        args.entryTransition == LiveRoomEntryTransition.homeTopRightRoomIcon;

    return PageRouteBuilder<void>(
      opaque: false,
      maintainState: true,
      transitionDuration: isHomeTopRightEntry
          ? const Duration(milliseconds: 430)
          : const Duration(milliseconds: 240),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) =>
          LiveRoomPresenceShellPage(
            roomName: args.roomName,
            roomId: args.roomId,
            language: args.language,
            modeTitle: args.modeTitle,
            initialOnlineCount: args.onlineCount,
            currentUser: currentUser,
            lockPassword: args.lockPassword,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return isHomeTopRightEntry
            ? _homeTopRightRoomIconTransition(animation, child)
            : _standardLiveRoomTransition(animation, child);
      },
    );
  }

  static Widget _standardLiveRoomTransition(
    Animation<double> animation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.018, 0.012),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }

  static Widget _homeTopRightRoomIconTransition(
    Animation<double> animation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.06, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    final preloadReveal = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.72, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.10, -0.045),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween<double>(begin: 0.965, end: 1).animate(preloadReveal),
          child: AnimatedBuilder(
            animation: preloadReveal,
            child: child,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(32 * (1 - preloadReveal.value)),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}
