import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';

class LiveRoomSocketService {
  LiveRoomSocketService({String? httpBaseUrl})
      : _httpBaseUrl = httpBaseUrl ?? AppConstants.apiBaseUrl;

  final String _httpBaseUrl;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final StreamController<LiveRoomSocketEvent> _eventsController =
      StreamController<LiveRoomSocketEvent>.broadcast();

  Stream<LiveRoomSocketEvent> get events => _eventsController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect({
    required String roomId,
    required String userId,
    required String displayName,
  }) async {
    await disconnect();

    final uri = _roomSocketUri(
      roomId: roomId,
      userId: userId,
      displayName: displayName,
    );

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;

    _subscription = channel.stream.listen(
      _handleRawEvent,
      onError: (Object error) {
        _eventsController.add(
          LiveRoomSocketEvent(
            type: 'system.client_error',
            payload: {'message': error.toString()},
          ),
        );
      },
      onDone: () {
        _eventsController.add(
          const LiveRoomSocketEvent(
            type: 'system.disconnected',
            payload: {},
          ),
        );
      },
      cancelOnError: false,
    );

    await channel.ready;
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
  }

  void sendPing({String? requestId}) {
    sendEvent(
      type: 'ping',
      requestId: requestId ?? 'ping-${DateTime.now().millisecondsSinceEpoch}',
      payload: const {},
    );
  }

  void sendRoomMessage({
    required String text,
    required String roomId,
    required String userId,
    String? requestId,
  }) {
    sendEvent(
      type: 'room.message.send',
      roomId: roomId,
      userId: userId,
      requestId: requestId ?? 'msg-${DateTime.now().millisecondsSinceEpoch}',
      payload: {'text': text},
    );
  }

  void sendRoomImageMessage({
    required String imageUrl,
    required String storageKey,
    required String filename,
    required int sizeBytes,
    required String roomId,
    required String userId,
    String? requestId,
  }) {
    sendRoomMessage(
      text: _cdnImageMessagePayload(
        imageUrl: imageUrl,
        storageKey: storageKey,
        filename: filename,
        sizeBytes: sizeBytes,
      ),
      roomId: roomId,
      userId: userId,
      requestId: requestId ?? 'img-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  void sendSeatOccupy({
    required String roomId,
    required String userId,
    required int seatIndex,
  }) {
    sendEvent(
      type: 'room.seat.occupy',
      roomId: roomId,
      userId: userId,
      requestId: 'seat-occupy-${DateTime.now().millisecondsSinceEpoch}',
      payload: {'seat_index': seatIndex},
    );
  }

  void sendSeatLeave({
    required String roomId,
    required String userId,
    required int seatIndex,
  }) {
    sendEvent(
      type: 'room.seat.leave',
      roomId: roomId,
      userId: userId,
      requestId: 'seat-leave-${DateTime.now().millisecondsSinceEpoch}',
      payload: {'seat_index': seatIndex},
    );
  }

  void sendSeatSwitch({
    required String roomId,
    required String userId,
    required int fromSeatIndex,
    required int toSeatIndex,
  }) {
    sendEvent(
      type: 'room.seat.switch',
      roomId: roomId,
      userId: userId,
      requestId: 'seat-switch-${DateTime.now().millisecondsSinceEpoch}',
      payload: {
        'from_seat_index': fromSeatIndex,
        'to_seat_index': toSeatIndex,
      },
    );
  }

  void sendSeatLock({
    required String roomId,
    required String userId,
    required int seatIndex,
  }) {
    sendEvent(
      type: 'room.seat.lock',
      roomId: roomId,
      userId: userId,
      requestId: 'seat-lock-${DateTime.now().millisecondsSinceEpoch}',
      payload: {'seat_index': seatIndex},
    );
  }

  void sendSeatUnlock({
    required String roomId,
    required String userId,
    required int seatIndex,
  }) {
    sendEvent(
      type: 'room.seat.unlock',
      roomId: roomId,
      userId: userId,
      requestId: 'seat-unlock-${DateTime.now().millisecondsSinceEpoch}',
      payload: {'seat_index': seatIndex},
    );
  }

  void sendSelfMute({
    required String roomId,
    required String userId,
    required bool muted,
  }) {
    sendEvent(
      type: muted ? 'room.mic.self_mute' : 'room.mic.self_unmute',
      roomId: roomId,
      userId: userId,
      requestId: 'self-mute-${DateTime.now().millisecondsSinceEpoch}',
      payload: {'target_user_id': userId, 'muted': muted},
    );
  }

  void sendAdminMute({
    required String roomId,
    required String userId,
    required String targetUserId,
    required bool muted,
  }) {
    sendEvent(
      type: muted ? 'room.mic.admin_mute' : 'room.mic.admin_unmute',
      roomId: roomId,
      userId: userId,
      requestId: 'admin-mute-${DateTime.now().millisecondsSinceEpoch}',
      payload: {'target_user_id': targetUserId, 'muted': muted},
    );
  }

  void sendEvent({
    required String type,
    String? roomId,
    String? userId,
    String? requestId,
    Map<String, dynamic> payload = const {},
  }) {
    final channel = _channel;
    if (channel == null) {
      _eventsController.add(
        const LiveRoomSocketEvent(
          type: 'system.client_error',
          payload: {'message': 'Room socket is not connected.'},
        ),
      );
      return;
    }

    final envelope = <String, dynamic>{
      'type': type,
      'payload': payload,
    };

    if (roomId != null) envelope['room_id'] = roomId;
    if (userId != null) envelope['user_id'] = userId;
    if (requestId != null) envelope['request_id'] = requestId;

    channel.sink.add(jsonEncode(envelope));
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventsController.close();
  }

  Uri _roomSocketUri({
    required String roomId,
    required String userId,
    required String displayName,
  }) {
    final httpUri = Uri.parse(_httpBaseUrl);
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';

    return httpUri.replace(
      scheme: scheme,
      path: '/ws/rooms/$roomId',
      queryParameters: {
        'user_id': userId,
        'display_name': displayName,
      },
    );
  }

  String _cdnImageMessagePayload({
    required String imageUrl,
    required String storageKey,
    required String filename,
    required int sizeBytes,
  }) {
    return 'vm-cdn-image://${Uri.encodeComponent(imageUrl)}'
        '?storage_key=${Uri.encodeComponent(storageKey)}'
        '&name=${Uri.encodeComponent(filename)}'
        '&size=$sizeBytes';
  }

  void _handleRawEvent(dynamic rawEvent) {
    try {
      final decoded = jsonDecode(rawEvent.toString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('WebSocket event must be a JSON object.');
      }
      _eventsController.add(LiveRoomSocketEvent.fromJson(decoded));
    } catch (error) {
      _eventsController.add(
        LiveRoomSocketEvent(
          type: 'system.client_error',
          payload: {'message': error.toString(), 'raw': rawEvent.toString()},
        ),
      );
    }
  }
}

class LiveRoomSocketEvent {
  const LiveRoomSocketEvent({
    required this.type,
    required this.payload,
    this.requestId,
    this.ok,
    this.code,
    this.message,
  });

  factory LiveRoomSocketEvent.fromJson(Map<String, dynamic> json) {
    final payloadValue = json['payload'];
    return LiveRoomSocketEvent(
      type: json['type']?.toString() ?? 'unknown',
      requestId: json['request_id']?.toString(),
      ok: json['ok'] is bool ? json['ok'] as bool : null,
      code: json['code']?.toString(),
      message: json['message']?.toString(),
      payload: payloadValue is Map<String, dynamic>
          ? payloadValue
          : <String, dynamic>{},
    );
  }

  final String type;
  final String? requestId;
  final bool? ok;
  final String? code;
  final String? message;
  final Map<String, dynamic> payload;
}
