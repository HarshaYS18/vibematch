import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../live_room_presence_shell_page.dart';
import 'live_room_route_args.dart';

class LiveRoomRoutes {
  const LiveRoomRoutes._();

  static const Duration _standardEntryDuration = Duration(milliseconds: 420);
  static const Duration _homeTopRightEntryDuration = Duration(milliseconds: 680);
  static const Duration _exitDuration = Duration(milliseconds: 340);

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
          ? _homeTopRightEntryDuration
          : _standardEntryDuration,
      reverseTransitionDuration: _exitDuration,
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
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.028, 0.018),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.988, end: 1).animate(curved),
          child: child,
        ),
      ),
    );
  }

  static Widget _homeTopRightRoomIconTransition(
    Animation<double> animation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.04, 1, curve: Curves.easeOutCubic),
      reverseCurve: Curves.easeInCubic,
    );
    final preloadReveal = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.84, curve: Curves.easeOutQuart),
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.12, -0.055),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween<double>(begin: 0.955, end: 1).animate(preloadReveal),
          child: AnimatedBuilder(
            animation: preloadReveal,
            child: child,
            builder: (context, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(
                  34 * (1 - preloadReveal.value),
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}
