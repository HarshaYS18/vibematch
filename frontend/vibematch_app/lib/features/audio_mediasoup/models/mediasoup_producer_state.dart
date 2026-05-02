class MediasoupProducerState {
  const MediasoupProducerState({
    required this.producerId,
    required this.peerId,
    required this.kind,
    this.seatNo,
  });

  final String producerId;
  final String peerId;
  final String kind;
  final int? seatNo;

  factory MediasoupProducerState.fromJson(Map<String, dynamic> json) {
    return MediasoupProducerState(
      producerId: json['producerId']?.toString() ?? '',
      peerId: json['peerId']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'audio',
      seatNo: _asNullableInt(json['seatNo']),
    );
  }

  static int? _asNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
