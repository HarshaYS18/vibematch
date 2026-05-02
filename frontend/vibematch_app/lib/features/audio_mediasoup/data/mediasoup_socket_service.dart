import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/mediasoup_producer_state.dart';
import '../models/mediasoup_room_state.dart';

class MediasoupSocketService {
  MediasoupSocketService();

  io.Socket? _socket;
  String? _serverUrl;
  String? _roomId;
  String? _peerId;

  final StreamController<String> _logController = StreamController<String>.broadcast();
  final StreamController<List<dynamic>> _seatEventController = StreamController<List<dynamic>>.broadcast();
  final StreamController<MediasoupProducerState> _producerController = StreamController<MediasoupProducerState>.broadcast();
  final StreamController<String> _producerClosedController = StreamController<String>.broadcast();
  final StreamController<String> _peerLeftController = StreamController<String>.broadcast();

  Stream<String> get logs => _logController.stream;
  Stream<List<dynamic>> get seatEvents => _seatEventController.stream;
  Stream<MediasoupProducerState> get newProducers => _producerController.stream;
  Stream<String> get producerClosedEvents => _producerClosedController.stream;
  Stream<String> get peerLeftEvents => _peerLeftController.stream;

  bool get connected => _socket?.connected ?? false;
  String? get serverUrl => _serverUrl;
  String? get roomId => _roomId;
  String? get peerId => _peerId;

  Future<MediasoupRoomState> connectAndJoin({
    required String serverUrl,
    required String roomId,
    required String peerId,
    String? audioToken,
  }) async {
    await disconnect();

    _serverUrl = serverUrl;
    _roomId = roomId;
    _peerId = peerId;

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(8)
          .setReconnectionDelay(600)
          .build(),
    );

    _registerEventHandlers();

    final completer = Completer<void>();

    _socket!.once('connect', (_) {
      _log('connected to $serverUrl');
      if (!completer.isCompleted) completer.complete();
    });

    _socket!.once('connect_error', (dynamic error) {
      _log('connect error: $error');
      if (!completer.isCompleted) {
        completer.completeError(Exception('Socket connect error: $error'));
      }
    });

    _socket!.connect();
    await completer.future.timeout(const Duration(seconds: 8));

    final response = await _emitAck('joinRoom', <String, dynamic>{
      'roomId': roomId,
      'peerId': peerId,
      if (audioToken != null && audioToken.isNotEmpty) 'audioToken': audioToken,
    });

    _ensureOk(response, 'joinRoom');

    _log('joined room=$roomId peer=$peerId');

    return MediasoupRoomState.fromJoinResponse(
      roomId: roomId,
      json: response,
    );
  }

  Future<Map<String, dynamic>> takeSeat(int seatNo) async {
    final response = await _emitAck('takeSeat', _roomPayload(<String, dynamic>{
      'seatNo': seatNo,
    }));

    _ensureOk(response, 'takeSeat');
    _log('take seat $seatNo');
    return response;
  }

  Future<Map<String, dynamic>> leaveSeat() async {
    final response = await _emitAck('leaveSeat', _roomPayload());
    _ensureOk(response, 'leaveSeat');
    _log('leave seat');
    return response;
  }

  Future<Map<String, dynamic>> setSelfMuted(bool muted) async {
    final response = await _emitAck('setSelfMuted', _roomPayload(<String, dynamic>{
      'muted': muted,
    }));

    _ensureOk(response, 'setSelfMuted');
    _log('self muted=$muted');
    return response;
  }

  Future<Map<String, dynamic>> setAdminMuted({
    required String targetPeerId,
    required bool muted,
  }) async {
    final response = await _emitAck('setAdminMuted', <String, dynamic>{
      'roomId': _requireRoomId(),
      'targetPeerId': targetPeerId,
      'muted': muted,
    });

    _ensureOk(response, 'setAdminMuted');
    _log('admin muted peer=$targetPeerId muted=$muted');
    return response;
  }

  Future<Map<String, dynamic>> createTransport({
    required String direction,
  }) async {
    final response = await _emitAck('createWebRtcTransport', _roomPayload(<String, dynamic>{
      'direction': direction,
    }));

    _ensureOk(response, 'createWebRtcTransport');
    return response;
  }

  Future<Map<String, dynamic>> connectTransport({
    required String transportId,
    required Map<String, dynamic> dtlsParameters,
  }) async {
    final response = await _emitAck('connectTransport', _roomPayload(<String, dynamic>{
      'transportId': transportId,
      'dtlsParameters': dtlsParameters,
    }));

    _ensureOk(response, 'connectTransport');
    return response;
  }

  Future<Map<String, dynamic>> produce({
    required String transportId,
    required String kind,
    required Map<String, dynamic> rtpParameters,
  }) async {
    final response = await _emitAck('produce', _roomPayload(<String, dynamic>{
      'transportId': transportId,
      'kind': kind,
      'rtpParameters': rtpParameters,
    }));

    _ensureOk(response, 'produce');
    return response;
  }

  Future<Map<String, dynamic>> consume({
    required String producerId,
    required String transportId,
    required Map<String, dynamic> rtpCapabilities,
  }) async {
    final response = await _emitAck('consume', _roomPayload(<String, dynamic>{
      'producerId': producerId,
      'transportId': transportId,
      'rtpCapabilities': rtpCapabilities,
    }));

    _ensureOk(response, 'consume');
    return response;
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;

    if (socket != null) {
      socket.dispose();
    }

    _roomId = null;
    _peerId = null;
  }

  void dispose() {
    disconnect();
    _logController.close();
    _seatEventController.close();
    _producerController.close();
    _producerClosedController.close();
    _peerLeftController.close();
  }

  void _registerEventHandlers() {
    final socket = _socket;
    if (socket == null) return;

    socket.on('disconnect', (_) => _log('socket disconnected'));
    socket.on('reconnect', (_) => _log('socket reconnected'));
    socket.on('connect_error', (dynamic error) => _log('connect error: $error'));

    socket.on('peerJoined', (dynamic data) {
      final peerId = _asMap(data)['peerId']?.toString() ?? 'unknown';
      _log('peer joined: $peerId');
    });

    socket.on('peerLeft', (dynamic data) {
      final peerId = _asMap(data)['peerId']?.toString() ?? 'unknown';
      _log('peer left: $peerId');
      _peerLeftController.add(peerId);
    });

    socket.on('seatsUpdated', (dynamic data) {
      final map = _asMap(data);
      final seats = map['seats'];
      if (seats is List) {
        _seatEventController.add(seats);
      }
      _log('seats updated');
    });

    socket.on('newProducer', (dynamic data) {
      final map = _asMap(data);
      final producer = MediasoupProducerState.fromJson(map);
      if (producer.producerId.isNotEmpty) {
        _producerController.add(producer);
        _log('new producer peer=${producer.peerId} producer=${producer.producerId}');
      }
    });

    socket.on('producerClosed', (dynamic data) {
      final producerId = _asMap(data)['producerId']?.toString() ?? 'unknown';
      _producerClosedController.add(producerId);
      _log('producer closed: $producerId');
    });
  }

  Future<Map<String, dynamic>> _emitAck(String event, Map<String, dynamic> payload) async {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      throw StateError('Socket is not connected');
    }

    final completer = Completer<Map<String, dynamic>>();

    socket.emitWithAck(
      event,
      payload,
      ack: (dynamic data) {
        if (!completer.isCompleted) {
          completer.complete(_asMap(data));
        }
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException('$event timed out'),
    );
  }

  Map<String, dynamic> _roomPayload([Map<String, dynamic>? extra]) {
    return <String, dynamic>{
      'roomId': _requireRoomId(),
      'peerId': _requirePeerId(),
      ...?extra,
    };
  }

  String _requireRoomId() {
    final value = _roomId;
    if (value == null || value.isEmpty) {
      throw StateError('roomId is not set');
    }
    return value;
  }

  String _requirePeerId() {
    final value = _peerId;
    if (value == null || value.isEmpty) {
      throw StateError('peerId is not set');
    }
    return value;
  }

  void _ensureOk(Map<String, dynamic> response, String event) {
    if (response['ok'] == true) return;
    throw Exception('$event failed: ${response['error'] ?? 'unknown error'}');
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  void _log(String message) {
    _logController.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
  }
}
