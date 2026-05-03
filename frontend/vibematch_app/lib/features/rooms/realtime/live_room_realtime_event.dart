class LiveRoomRealtimeEvent {
  const LiveRoomRealtimeEvent({
    required this.type,
    required this.payload,
  });

  final String type;
  final Map<String, dynamic> payload;

  factory LiveRoomRealtimeEvent.fromJson(Map<String, dynamic> json) {
    return LiveRoomRealtimeEvent(
      type: json['type']?.toString() ?? 'unknown',
      payload: json,
    );
  }
}
