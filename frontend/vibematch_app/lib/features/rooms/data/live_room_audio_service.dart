import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/network/vm_media_config.dart';
import '../presentation/live_room_models.dart';

class LiveRoomAudioService {
  LiveRoomAudioService._();

  static final LiveRoomAudioService instance = LiveRoomAudioService._();

  io.Socket? _socket;
  String? _roomId;
  String? _peerId;
  SeatUser? _currentUser;
  MediaStream? _localAudioStream;
  bool _joined = false;
  bool _connecting = false;
  bool _selfMuted = true;
  bool _seated = false;

  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> joined = ValueNotifier<bool>(false);
  final ValueNotifier<bool> localMicCapturing = ValueNotifier<bool>(false);
  final ValueNotifier<List<AudioSeatSnapshot>> seats = ValueNotifier<List<AudioSeatSnapshot>>(<AudioSeatSnapshot>[]);
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  bool get isJoined => _joined;
  String? get roomId => _roomId;
  String? get peerId => _peerId;

  Future<void> joinRoom({required String roomId, required SeatUser currentUser}) async {
    final safeRoomId = roomId.trim().isEmpty ? 'VM257808' : roomId.trim();
    final safePeerId = '${safeRoomId}_${currentUser.id}'.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');

    if (_joined && _roomId == safeRoomId && _peerId == safePeerId) return;

    _roomId = safeRoomId;
    _peerId = safePeerId;
    _currentUser = currentUser;

    await _connectIfNeeded();
    _emitWithAck(
      'joinRoom',
      <String, Object?>{
        'roomId': safeRoomId,
        'peerId': safePeerId,
      },
      onAck: (ack) {
        if (ack['ok'] == true) {
          _joined = true;
          joined.value = true;
          seats.value = AudioSeatSnapshot.listFromJson(ack['room']?['seats']);
          _debug('audio join ok room=$safeRoomId peer=$safePeerId');
        } else {
          _setError('Audio join failed: ${ack['error'] ?? 'unknown'}');
        }
      },
    );
  }

  void takeSeat(int seatIndex) {
    if (!_canSendRoomEvent() || seatIndex < 0) return;
    _emitWithAck(
      'takeSeat',
      <String, Object?>{'roomId': _roomId, 'peerId': _peerId, 'seatNo': seatIndex + 1},
      onAck: (ack) {
        _handleSeatAck(ack);
        if (ack['ok'] == true) {
          _seated = true;
          unawaited(_syncLocalMicCapture());
        }
      },
    );
  }

  void leaveSeat() {
    if (!_canSendRoomEvent()) return;
    _seated = false;
    _selfMuted = true;
    unawaited(_stopLocalMicCapture());
    _emitWithAck(
      'leaveSeat',
      <String, Object?>{'roomId': _roomId, 'peerId': _peerId},
      onAck: _handleSeatAck,
    );
  }

  void setSelfMuted(bool muted) {
    if (!_canSendRoomEvent()) return;
    _selfMuted = muted;
    unawaited(_syncLocalMicCapture());
    _emitWithAck(
      'setSelfMuted',
      <String, Object?>{'roomId': _roomId, 'peerId': _peerId, 'muted': muted},
      onAck: _handleSeatAck,
    );
  }

  Future<void> leaveRoom() async {
    await _stopLocalMicCapture();
    _joined = false;
    _seated = false;
    _selfMuted = true;
    joined.value = false;
    seats.value = <AudioSeatSnapshot>[];
    _roomId = null;
    _peerId = null;
    _currentUser = null;
    final socket = _socket;
    _socket = null;
    socket?.dispose();
    connected.value = false;
  }

  Future<void> _connectIfNeeded() async {
    if (_socket?.connected == true || _connecting) return;
    _connecting = true;

    final socket = io.io(
      VmMediaConfig.audioUrl,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(20)
          .setReconnectionDelay(700)
          .build(),
    );

    socket.onConnect((_) {
      connected.value = true;
      _debug('audio socket connected ${VmMediaConfig.audioUrl}');
    });

    socket.onDisconnect((_) {
      connected.value = false;
      _joined = false;
      joined.value = false;
      _seated = false;
      unawaited(_stopLocalMicCapture());
      _debug('audio socket disconnected');
    });

    socket.onConnectError((dynamic error) {
      _setError('Audio socket connect error: $error');
    });

    socket.onError((dynamic error) {
      _setError('Audio socket error: $error');
    });

    socket.on('seatsUpdated', (dynamic payload) {
      if (payload is Map) {
        final nextSeats = AudioSeatSnapshot.listFromJson(payload['seats']);
        seats.value = nextSeats;
        _seated = nextSeats.any((seat) => seat.peerId == _peerId);
        if (!_seated) {
          _selfMuted = true;
          unawaited(_stopLocalMicCapture());
        }
        _debug('audio seats updated count=${seats.value.length} seated=$_seated');
      }
    });

    socket.on('peerJoined', (dynamic payload) {
      _debug('audio peer joined $payload');
    });

    socket.on('peerLeft', (dynamic payload) {
      _debug('audio peer left $payload');
    });

    socket.on('newProducer', (dynamic payload) {
      _debug('audio new producer $payload');
    });

    socket.on('producerClosed', (dynamic payload) {
      _debug('audio producer closed $payload');
    });

    _socket = socket;
    socket.connect();
    _connecting = false;
  }

  Future<void> _syncLocalMicCapture() async {
    if (_seated && !_selfMuted) {
      await _startLocalMicCapture();
    } else {
      await _stopLocalMicCapture();
    }
  }

  Future<void> _startLocalMicCapture() async {
    if (_localAudioStream != null) return;
    try {
      final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': <String, dynamic>{
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      });
      for (final track in stream.getAudioTracks()) {
        track.enabled = true;
      }
      _localAudioStream = stream;
      localMicCapturing.value = true;
      _debug('local mic capture started tracks=${stream.getAudioTracks().length}');
    } catch (error) {
      _setError('Local mic capture failed: $error');
    }
  }

  Future<void> _stopLocalMicCapture() async {
    final stream = _localAudioStream;
    if (stream == null) return;
    _localAudioStream = null;
    for (final track in stream.getTracks()) {
      try {
        track.stop();
      } catch (_) {}
    }
    try {
      await stream.dispose();
    } catch (_) {}
    localMicCapturing.value = false;
    _debug('local mic capture stopped');
  }

  bool _canSendRoomEvent() {
    return _socket?.connected == true && _joined && _roomId != null && _peerId != null;
  }

  void _emitWithAck(String event, Map<String, Object?> payload, {required void Function(Map<String, dynamic> ack) onAck}) {
    final socket = _socket;
    if (socket == null) return;
    _debug('audio send $event $payload');
    socket.emitWithAck(event, payload, ack: (dynamic rawAck) {
      final ack = rawAck is Map ? Map<String, dynamic>.from(rawAck) : <String, dynamic>{'ok': false, 'error': 'Invalid ack'};
      onAck(ack);
    });
  }

  void _handleSeatAck(Map<String, dynamic> ack) {
    if (ack['ok'] == true) {
      seats.value = AudioSeatSnapshot.listFromJson(ack['seats']);
    } else {
      _setError('Audio seat action failed: ${ack['error'] ?? 'unknown'}');
    }
  }

  void _setError(String message) {
    lastError.value = message;
    _debug(message);
  }

  void _debug(String message) {
    // ignore: avoid_print
    print('[VibeMatchAudio] $message');
  }
}

class AudioSeatSnapshot {
  const AudioSeatSnapshot({required this.seatNo, this.peerId, this.producerId, this.selfMuted = false, this.adminMuted = false, this.locked = false});

  final int seatNo;
  final String? peerId;
  final String? producerId;
  final bool selfMuted;
  final bool adminMuted;
  final bool locked;

  factory AudioSeatSnapshot.fromJson(Map<String, dynamic> json) {
    return AudioSeatSnapshot(
      seatNo: int.tryParse(json['seatNo']?.toString() ?? '') ?? 0,
      peerId: json['peerId']?.toString(),
      producerId: json['producerId']?.toString(),
      selfMuted: json['selfMuted'] == true,
      adminMuted: json['adminMuted'] == true,
      locked: json['locked'] == true,
    );
  }

  static List<AudioSeatSnapshot> listFromJson(dynamic raw) {
    if (raw is! List) return const <AudioSeatSnapshot>[];
    return raw.whereType<Map>().map((item) => AudioSeatSnapshot.fromJson(Map<String, dynamic>.from(item))).toList();
  }
}
