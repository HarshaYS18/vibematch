class LiveRoomSeatApplicationEvent {
  const LiveRoomSeatApplicationEvent({
    required this.id,
    required this.roomId,
    required this.applicantUserId,
    required this.applicantName,
    required this.seatIndex,
    required this.createdAt,
    required this.expiresAt,
  });

  final String id;
  final String roomId;
  final String applicantUserId;
  final String applicantName;
  final int seatIndex;
  final DateTime createdAt;
  final DateTime expiresAt;

  factory LiveRoomSeatApplicationEvent.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return LiveRoomSeatApplicationEvent(
      id: json['id']?.toString() ?? now.microsecondsSinceEpoch.toString(),
      roomId: json['room_id']?.toString() ?? '',
      applicantUserId: json['applicant_user_id']?.toString() ?? '',
      applicantName: json['applicant_name']?.toString() ?? 'User',
      seatIndex: int.tryParse(json['seat_index']?.toString() ?? '') ?? -1,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? now,
      expiresAt:
          DateTime.tryParse(json['expires_at']?.toString() ?? '') ??
          now.add(const Duration(seconds: 20)),
    );
  }
}
