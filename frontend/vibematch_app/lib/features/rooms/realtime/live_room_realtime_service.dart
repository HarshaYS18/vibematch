import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_local_storage.dart';
import 'live_room_realtime_event.dart';

class LiveRoomRealtimeService {
  LiveRoomRealtimeService({
    AuthLocalStorage? storage,
  }) : _storage = storage ?? AuthLocalStorage();

  final AuthLocalStorage _storage;
  final StreamController<LiveRoomRealtimeEvent> _eventsController = StreamController<LiveRoomRealtimeEvent>.broadcast();
  final StreamController<String> _logsController = StreamController<String>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  String? _roomId;
  bool _connected = false;

  Stream<LiveRoomRealtimeEvent> get events => _eventsController.stream;
  Stream<String> get logs => _logsController.stream;
  bool get connected => _connected;

  Future<void> connect(String roomId) async {
    await disconnect();
    final token = await _storage.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Missing auth token for room realtime connection');
    }

    _roomId = roomId;
    final wsBase = AppConstants.apiBaseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    final uri = Uri.parse('$wsBase/ws/rooms/$roomId').replace(
      queryParameters: <String, String>{'token': token},
    );

    final channel = WebSocketChannel.connect(uri);
    _channel = channel;
    _connected = true;
    _log('connected to live room websocket $roomId');

    _subscription = channel.stream.listen(
      _handleRawMessage,
      onError: (Object error) {
        _connected = false;
        _log('live room websocket error: $error');
      },
      onDone: () {
        _connected = false;
        _log('live room websocket closed');
      },
      cancelOnError: false,
    );
  }

  void send(String type, [Map<String, dynamic>? payload]) {
    final channel = _channel;
    if (channel == null || !_connected) return;

    final event = <String, dynamic>{
      'type': type,
      ...?payload,
    };
    channel.sink.add(jsonEncode(event));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    final channel = _channel;
    _channel = null;
    _connected = false;
    _roomId = null;
    await channel?.sink.close();
  }

  Future<void> dispose() async {
    await disconnect();
    await _eventsController.close();
    await _logsController.close();
  }

  void _handleRawMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw.toString());
      if (decoded is Map<String, dynamic>) {
        _eventsController.add(LiveRoomRealtimeEvent.fromJson(decoded));
      } else if (decoded is Map) {
        _eventsController.add(LiveRoomRealtimeEvent.fromJson(decoded.cast<String, dynamic>()));
      }
    } catch (error) {
      _log('invalid realtime payload: $error');
    }
  }

  void _log(String message) {
    final prefix = _roomId == null ? 'room' : _roomId!;
    _logsController.add('[$prefix] $message');
  }
}
