import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../room_session/data/room_session_repository.dart';

import 'lifecycle/live_room_lifecycle_module.dart';
import 'live_room_controller_bundle.dart';
import 'seats/live_room_seats_module.dart';

class LiveRoomControllerScope extends ConsumerStatefulWidget {
  const LiveRoomControllerScope({
    super.key,
    required this.config,
    required this.builder,
  });

  final LiveRoomControllerConfig config;
  final Widget Function(BuildContext context, LiveRoomControllerBundle bundle)
  builder;

  @override
  ConsumerState<LiveRoomControllerScope> createState() =>
      _LiveRoomControllerScopeState();
}

class _LiveRoomControllerScopeState
    extends ConsumerState<LiveRoomControllerScope> {
  late final LiveRoomControllerBundle bundle;

  @override
  void initState() {
    super.initState();

    bundle = LiveRoomControllerBundle(
      config: widget.config,
      roomSessionRepository: ref.read(
        roomSessionRepositoryProvider(widget.config.roomId).notifier,
      ),
      contextGetter: () => context,
      mountedGetter: () => mounted,
    );
    bundle.initialize(
      onRoomStateChanged: () =>
          LiveRoomLifecycleModule.onRoomStateChanged(bundle),
      onSeatInviteUpdate: () =>
          LiveRoomSeatsModule.handleSeatInviteUpdate(bundle),
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
  Widget build(BuildContext context) {
    final canonical = ref.watch(
      roomSessionRepositoryProvider(widget.config.roomId),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) bundle.applyCanonicalRoomState(canonical);
    });
    return widget.builder(context, bundle);
  }
}
