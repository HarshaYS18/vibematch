import 'package:flutter/material.dart';

import '../../auth/models/current_user.dart';
import 'live_room_presence_shell_page.dart';

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
  @override
  Widget build(BuildContext context) {
    return LiveRoomPresenceShellPage(
      roomName: widget.roomName,
      roomId: widget.roomId,
      language: widget.language,
      modeTitle: widget.modeTitle,
      initialOnlineCount: widget.onlineCount,
      currentUser: widget.currentUser,
    );
  }
}
