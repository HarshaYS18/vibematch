import 'package:flutter/material.dart';

import 'gifts/live_room_gifts_module.dart';
import 'lifecycle/live_room_lifecycle_module.dart';
import 'live_room_controller_bundle.dart';
import 'seats/live_room_seats_module.dart';

class LiveRoomControllerScope extends StatefulWidget {
  const LiveRoomControllerScope({
    super.key,
    required this.config,
    required this.builder,
  });

  final LiveRoomControllerConfig config;
  final Widget Function(BuildContext context, LiveRoomControllerBundle bundle)
  builder;

  @override
  State<LiveRoomControllerScope> createState() =>
      _LiveRoomControllerScopeState();
}

class _LiveRoomControllerScopeState extends State<LiveRoomControllerScope> {
  late final LiveRoomControllerBundle bundle;

  @override
  void initState() {
    super.initState();

    bundle = LiveRoomControllerBundle(
      config: widget.config,
      contextGetter: () => context,
      mountedGetter: () => mounted,
    );
    bundle.syncLuckyPacketBeforeRoomRevision = () {
      LiveRoomGiftsModule.bindLuckyPacketBusIfReady(bundle);
    };

    bundle.initialize(
      onRoomStateChanged: () =>
          LiveRoomLifecycleModule.onRoomStateChanged(bundle),
      onSeatInviteUpdate: () =>
          LiveRoomSeatsModule.handleSeatInviteUpdate(bundle),
      onMembershipChanged: () => bundle.notifyRoomChanged(),
      onMemberRequestChanged: () => bundle.notifyRoomChanged(),
    );

    LiveRoomLifecycleModule.startRoomPresence(bundle);
    LiveRoomLifecycleModule.syncPresenceRoomDetails(bundle);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      LiveRoomSeatsModule.autoOccupySeatOneForHostOrAdmin(bundle);
      LiveRoomSeatsModule.handleSeatInviteUpdate(bundle);
    });
  }

  @override
  void didUpdateWidget(covariant LiveRoomControllerScope oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.config.onlineCount != widget.config.onlineCount) {
      bundle.updateBackendOnlineCount(widget.config.onlineCount);
    }
  }

  @override
  void dispose() {
    bundle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, bundle);
}
