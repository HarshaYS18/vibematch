import 'package:flutter/material.dart';

import '../controllers/live_room_controller_bundle.dart';
import '../live_room_models.dart';
import '../live_room_route_args.dart';

class LiveRoomPerformanceHost extends StatefulWidget {
  const LiveRoomPerformanceHost({
    super.key,
    required this.args,
    required this.currentUser,
    required this.onToast,
    required this.builder,
  });

  final LiveRoomRouteArgs args;
  final SeatUser currentUser;
  final ValueChanged<String> onToast;
  final Widget Function(BuildContext context, LiveRoomControllerBundle bundle) builder;

  @override
  State<LiveRoomPerformanceHost> createState() => _LiveRoomPerformanceHostState();
}

class _LiveRoomPerformanceHostState extends State<LiveRoomPerformanceHost>
    with AutomaticKeepAliveClientMixin<LiveRoomPerformanceHost> {
  late final LiveRoomControllerBundle bundle;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    bundle = LiveRoomControllerBundle(
      roomName: widget.args.roomName,
      roomId: widget.args.roomId,
      modeTitle: widget.args.modeTitle,
      onlineCount: widget.args.onlineCount,
      currentUser: widget.currentUser,
      onUiChanged: _notifyUiChanged,
      onFinalGiftMessage: (entry) {
        bundle.roomMessageController.insertEntry(entry);
      },
      onToast: widget.onToast,
    );
    bundle.stateController.addListener(_notifyUiChanged);
  }

  @override
  void dispose() {
    bundle.stateController.removeListener(_notifyUiChanged);
    bundle.dispose();
    super.dispose();
  }

  void _notifyUiChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.builder(context, bundle);
  }
}
