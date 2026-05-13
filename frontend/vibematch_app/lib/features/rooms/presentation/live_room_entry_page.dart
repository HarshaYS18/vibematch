import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import '../controllers/live_room_lifecycle_controller.dart';
import 'live_room_page.dart';

class LiveRoomEntryPage extends StatefulWidget {
  const LiveRoomEntryPage({
    super.key,
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.modeTitle,
    required this.onlineCount,
    this.currentUser,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;
  final CurrentUser? currentUser;

  @override
  State<LiveRoomEntryPage> createState() => _LiveRoomEntryPageState();
}

class _LiveRoomEntryPageState extends State<LiveRoomEntryPage> {
  final LiveRoomLifecycleController _lifecycleController = LiveRoomLifecycleController();

  @override
  void initState() {
    super.initState();
    unawaited(_lifecycleController.join(widget.roomId));
  }

  @override
  void dispose() {
    unawaited(_lifecycleController.leave());
    _lifecycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LiveRoomPage(
      roomName: widget.roomName,
      roomId: widget.roomId,
      language: widget.language,
      modeTitle: widget.modeTitle,
      onlineCount: widget.onlineCount,
      currentUser: widget.currentUser,
    );
  }
}
