import 'package:flutter/material.dart';

import '../../../../app/app_routes.dart';
import '../../../../core/ui/vm_motion.dart';
import '../../data/live_room_media_signaling_service.dart';
import '../live_room_presence_shell_page.dart';
import 'live_room_route_args.dart';

class LiveRoomRoutes {
  const LiveRoomRoutes._();

  static const Duration _standardEntryDuration = Duration(milliseconds: 300);
  static const Duration _homeTopRightEntryDuration = Duration(milliseconds: 360);
  static const Duration _exitDuration = Duration(milliseconds: 240);

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
            ? _homeTopRightRoomIconTransition(context, animation, child)
            : VmMotion.buildPageTransition(
                context: context,
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                child: child,
                beginOffset: const Offset(0.025, 0.012),
              );
      },
    );
  }

  static Widget _homeTopRightRoomIconTransition(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return FadeTransition(opacity: animation, child: child);
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: VmMotion.enterCurve,
      reverseCurve: VmMotion.exitCurve,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.02, 1, curve: VmMotion.enterCurve),
      reverseCurve: VmMotion.exitCurve,
    );
    final preloadReveal = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, 0.92, curve: VmMotion.enterCurve),
      reverseCurve: VmMotion.exitCurve,
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.075, -0.028),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          alignment: Alignment.topRight,
          scale: Tween<double>(begin: 0.975, end: 1).animate(preloadReveal),
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }
}
