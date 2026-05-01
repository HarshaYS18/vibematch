class RoomRealtimeAuditLog {
  const RoomRealtimeAuditLog({
    required this.id,
    required this.roomId,
    required this.eventType,
    required this.createdAt,
    this.actorUserId,
    this.actorName,
    this.targetUserId,
    this.seatIndex,
    this.fromSeatIndex,
    this.toSeatIndex,
    this.requestId,
    this.reason,
    this.metadataJson,
  });

  factory RoomRealtimeAuditLog.fromJson(Map<String, dynamic> json) {
    return RoomRealtimeAuditLog(
      id: _intValue(json['id']),
      roomId: json['room_id']?.toString() ?? '',
      eventType: json['event_type']?.toString() ?? '',
      actorUserId: json['actor_user_id']?.toString(),
      actorName: json['actor_name']?.toString(),
      targetUserId: json['target_user_id']?.toString(),
      seatIndex: _nullableIntValue(json['seat_index']),
      fromSeatIndex: _nullableIntValue(json['from_seat_index']),
      toSeatIndex: _nullableIntValue(json['to_seat_index']),
      requestId: json['request_id']?.toString(),
      reason: json['reason']?.toString(),
      metadataJson: json['metadata_json'] is Map<String, dynamic>
          ? json['metadata_json'] as Map<String, dynamic>
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final int id;
  final String roomId;
  final String eventType;
  final String? actorUserId;
  final String? actorName;
  final String? targetUserId;
  final int? seatIndex;
  final int? fromSeatIndex;
  final int? toSeatIndex;
  final String? requestId;
  final String? reason;
  final Map<String, dynamic>? metadataJson;
  final DateTime createdAt;

  String get shortEventLabel {
    return eventType
        .replaceAll('room.', '')
        .replaceAll('seat.', '')
        .replaceAll('mic.', '')
        .replaceAll('_', ' ');
  }

  String get actionSummary {
    if (fromSeatIndex != null || toSeatIndex != null) {
      return 'Seat ${(fromSeatIndex ?? -1) + 1} → ${(toSeatIndex ?? -1) + 1}';
    }
    if (seatIndex != null) return 'Seat ${seatIndex! + 1}';
    if (targetUserId != null && targetUserId!.trim().isNotEmpty) {
      return 'Target $targetUserId';
    }
    return roomId;
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableIntValue(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
