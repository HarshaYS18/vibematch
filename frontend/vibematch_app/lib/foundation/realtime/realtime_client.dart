import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../logging/app_logger.dart';
import 'realtime_event_envelope.dart';

enum RealtimeConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

typedef RealtimeTokenProvider = String? Function();
typedef RealtimeSocketUriBuilder = Uri Function(String token);

class RealtimeClient {
  RealtimeClient({
    required RealtimeTokenProvider tokenProvider,
    required RealtimeSocketUriBuilder socketUriBuilder,
    AppLogger logger = const AppLogger(),
  })  : _tokenProvider = tokenProvider,
        _socketUriBuilder = socketUriBuilder,
        _logger = logger;

  final RealtimeTokenProvider _tokenProvider;
  final RealtimeSocketUriBuilder _socketUriBuilder;
  final AppLogger _logger;
  final RealtimeStreamCursor _cursor = RealtimeStreamCursor();

  final StreamController<RealtimeEventEnvelope> _eventController =
      StreamController<RealtimeEventEnvelope>.broadcast();
  final StreamController<RealtimeGap> _gapController =
      StreamController<RealtimeGap>.broadcast();
  final StreamController<RealtimeConnectionStatus> _statusController =
      StreamController<RealtimeConnectionStatus>.broadcast();
  final StreamController<int> _reconnectController =
      StreamController<int>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _connecting = false;
  bool _manuallyStopped = false;
  bool _everConnected = false;
  int _reconnectAttempt = 0;

  Stream<RealtimeEventEnvelope> get events => _eventController.stream;
  Stream<RealtimeGap> get gaps => _gapController.stream;
  Stream<RealtimeConnectionStatus> get statuses => _statusController.stream;
  Stream<int> get reconnects => _reconnectController.stream;
  bool get isConnected => _channel != null && !_connecting;

  Future<void> connect() async {
    if (_connecting || _channel != null) return;

    final token = _tokenProvider()?.trim();
    if (token == null || token.isEmpty) return;

    _manuallyStopped = false;
    _connecting = true;
    _emitStatus(
      _everConnected
          ? RealtimeConnectionStatus.reconnecting
          : RealtimeConnectionStatus.connecting,
    );

    try {
      final channel = WebSocketChannel.connect(_socketUriBuilder(token));
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleRawMessage,
        onDone: _handleDisconnected,
        onError: (Object error) {
          _logger.warning('Realtime', 'socket error', error);
          _handleDisconnected();
        },
        cancelOnError: true,
      );

      _reconnectAttempt = 0;
      _connecting = false;
      _emitStatus(RealtimeConnectionStatus.connected);
      if (_everConnected) {
        _reconnectController.add(DateTime.now().microsecondsSinceEpoch);
      }
      _everConnected = true;
      _startPing();
      sendRaw(const <String, dynamic>{'event': 'ping'});
    } catch (error) {
      _logger.warning('Realtime', 'connect failed', error);
      _channel = null;
      _connecting = false;
      _scheduleReconnect();
    }
  }

  void sendRaw(Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    try {
      channel.sink.add(jsonEncode(payload));
    } catch (error) {
      _logger.warning('Realtime', 'send failed', error);
      _handleDisconnected();
    }
  }

  void markResynced(String stream, int sequence) {
    _cursor.markResynced(stream, sequence);
  }

  void _handleRawMessage(dynamic raw) {
    if (raw is! String) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final json = decoded.cast<String, dynamic>();

      if (json['event'] == 'pong' &&
          json['sequence'] == null &&
          json['eventId'] == null &&
          json['event_id'] == null) {
        return;
      }

      final event = RealtimeEventEnvelope.fromJson(json);
      final decision = _cursor.accept(event);
      switch (decision) {
        case RealtimeSequenceDecision.accepted:
          _eventController.add(event);
          break;
        case RealtimeSequenceDecision.duplicate:
          _logger.debug(
            'Realtime',
            'ignored duplicate ${event.stream}#${event.sequence}',
          );
          break;
        case RealtimeSequenceDecision.gap:
          final gap = _cursor.gapFor(event);
          _logger.warning(
            'Realtime',
            'sequence gap ${gap.stream}: expected '
            '${gap.expectedSequence}, observed ${gap.observedSequence}',
          );
          _gapController.add(gap);
          break;
      }
    } catch (error) {
      _logger.warning('Realtime', 'ignored malformed event', error);
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      sendRaw(const <String, dynamic>{'event': 'ping'});
    });
  }

  void _handleDisconnected() {
    if (_channel == null && !_connecting) return;

    _subscription?.cancel();
    _subscription = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _channel = null;
    _connecting = false;
    _emitStatus(RealtimeConnectionStatus.disconnected);

    if (!_manuallyStopped) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manuallyStopped || _reconnectTimer != null) return;
    _reconnectAttempt += 1;
    final exponent = (_reconnectAttempt - 1).clamp(0, 4).toInt();
    final seconds = (1 << exponent).clamp(1, 15).toInt();
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(connect());
    });
  }

  void _emitStatus(RealtimeConnectionStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  Future<void> stop() async {
    _manuallyStopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final channel = _channel;
    _channel = null;
    try {
      await channel?.sink.close();
    } catch (_) {}
    _connecting = false;
    _emitStatus(RealtimeConnectionStatus.disconnected);
  }

  Future<void> dispose() async {
    await stop();
    await _eventController.close();
    await _gapController.close();
    await _statusController.close();
    await _reconnectController.close();
  }
}
