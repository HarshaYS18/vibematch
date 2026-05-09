class MediasoupSeatState {
  const MediasoupSeatState({
    required this.seatNo,
    this.peerId,
    this.producerId,
    this.selfMuted = false,
    this.adminMuted = false,
  });

  final int seatNo;
  final String? peerId;
  final String? producerId;
  final bool selfMuted;
  final bool adminMuted;

  bool get occupied => peerId != null && peerId!.isNotEmpty;
  bool get hasProducer => producerId != null && producerId!.isNotEmpty;
  bool get muted => selfMuted || adminMuted;

  factory MediasoupSeatState.fromJson(Map<String, dynamic> json) {
    return MediasoupSeatState(
      seatNo: _asInt(json['seatNo']),
      peerId: _asNullableString(json['peerId']),
      producerId: _asNullableString(json['producerId']),
      selfMuted: json['selfMuted'] == true,
      adminMuted: json['adminMuted'] == true,
    );
  }

  MediasoupSeatState copyWith({
    int? seatNo,
    String? peerId,
    String? producerId,
    bool? selfMuted,
    bool? adminMuted,
  }) {
    return MediasoupSeatState(
      seatNo: seatNo ?? this.seatNo,
      peerId: peerId ?? this.peerId,
      producerId: producerId ?? this.producerId,
      selfMuted: selfMuted ?? this.selfMuted,
      adminMuted: adminMuted ?? this.adminMuted,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _asNullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
