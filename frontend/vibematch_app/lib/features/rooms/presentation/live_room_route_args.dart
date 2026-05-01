class LiveRoomRouteArgs {
  const LiveRoomRouteArgs({
    required this.roomName,
    required this.roomId,
    required this.language,
    required this.modeTitle,
    required this.onlineCount,
  });

  final String roomName;
  final String roomId;
  final String language;
  final String modeTitle;
  final int onlineCount;
}
