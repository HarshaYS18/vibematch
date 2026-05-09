import 'mediasoup_producer_state.dart';
import 'mediasoup_seat_state.dart';

class MediasoupRoomState {
  const MediasoupRoomState({
    required this.roomId,
    required this.maxSpeakersPerRoom,
    required this.maxRoomPeers,
    required this.seats,
    required this.producers,
    this.rtpCapabilities,
    this.iceServers = const <Map<String, dynamic>>[],
  });

  final String roomId;
  final int maxSpeakersPerRoom;
  final int maxRoomPeers;
  final List<MediasoupSeatState> seats;
  final List<MediasoupProducerState> producers;
  final Map<String, dynamic>? rtpCapabilities;
  final List<Map<String, dynamic>> iceServers;

  int get occupiedSeatCount => seats.where((seat) => seat.occupied).length;
  int get activeProducerCount => producers.length;

  factory MediasoupRoomState.empty({
    String roomId = 'VM1001',
    int maxSpeakersPerRoom = 17,
    int maxRoomPeers = 250,
  }) {
    return MediasoupRoomState(
      roomId: roomId,
      maxSpeakersPerRoom: maxSpeakersPerRoom,
      maxRoomPeers: maxRoomPeers,
      seats: List<MediasoupSeatState>.generate(
        maxSpeakersPerRoom,
        (index) => MediasoupSeatState(seatNo: index + 1),
      ),
      producers: const <MediasoupProducerState>[],
    );
  }

  factory MediasoupRoomState.fromJoinResponse({
    required String roomId,
    required Map<String, dynamic> json,
  }) {
    final room = (json['room'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final rawSeats = room['seats'];
    final rawProducers = room['producers'];
    final rawIceServers = json['iceServers'];

    return MediasoupRoomState(
      roomId: room['id']?.toString() ?? roomId,
      maxSpeakersPerRoom: _asInt(room['maxSpeakersPerRoom'], fallback: 17),
      maxRoomPeers: _asInt(room['maxRoomPeers'], fallback: 250),
      seats: _parseSeats(rawSeats),
      producers: _parseProducers(rawProducers),
      rtpCapabilities: (json['rtpCapabilities'] as Map?)?.cast<String, dynamic>(),
      iceServers: _parseMapList(rawIceServers),
    );
  }

  MediasoupRoomState copyWith({
    String? roomId,
    int? maxSpeakersPerRoom,
    int? maxRoomPeers,
    List<MediasoupSeatState>? seats,
    List<MediasoupProducerState>? producers,
    Map<String, dynamic>? rtpCapabilities,
    List<Map<String, dynamic>>? iceServers,
  }) {
    return MediasoupRoomState(
      roomId: roomId ?? this.roomId,
      maxSpeakersPerRoom: maxSpeakersPerRoom ?? this.maxSpeakersPerRoom,
      maxRoomPeers: maxRoomPeers ?? this.maxRoomPeers,
      seats: seats ?? this.seats,
      producers: producers ?? this.producers,
      rtpCapabilities: rtpCapabilities ?? this.rtpCapabilities,
      iceServers: iceServers ?? this.iceServers,
    );
  }

  static List<MediasoupSeatState> seatsFromEvent(Map<String, dynamic> json) {
    return _parseSeats(json['seats']);
  }

  static List<MediasoupProducerState> _parseProducers(Object? raw) {
    if (raw is! List) return const <MediasoupProducerState>[];

    return raw
        .whereType<Map>()
        .map((item) => MediasoupProducerState.fromJson(item.cast<String, dynamic>()))
        .where((producer) => producer.producerId.isNotEmpty)
        .toList(growable: false);
  }

  static List<MediasoupSeatState> _parseSeats(Object? raw) {
    if (raw is! List) return MediasoupRoomState.empty().seats;

    return raw
        .whereType<Map>()
        .map((item) => MediasoupSeatState.fromJson(item.cast<String, dynamic>()))
        .where((seat) => seat.seatNo > 0)
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _parseMapList(Object? raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
  }

  static int _asInt(Object? value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
