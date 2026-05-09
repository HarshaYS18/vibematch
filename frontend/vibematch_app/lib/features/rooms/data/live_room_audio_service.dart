import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
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
  Device? _device;
  dynamic _sendTransport;
  dynamic _recvTransport;
  dynamic _audioProducer;
  dynamic _routerRtpCapabilities;
  Timer? _produceRetryTimer;
  int _produceRetryCount = 0;
  bool _joined = false;
  bool _connecting = false;
  bool _selfMuted = true;
  bool _seated = false;
  bool _deviceLoading = false;
  bool _sendTransportCreating = false;
  bool _recvTransportCreating = false;
  bool _producerCreating = false;

  final Set<String> _pendingProducerIds = <String>{};
  final Set<String> _consumingProducerIds = <String>{};
  final Set<String> _closingRemoteProducerIds = <String>{};
  final Map<String, RemoteProducerInfo> _producerInfoById = <String, RemoteProducerInfo>{};
  final Map<String, dynamic> _remoteConsumersByProducerId = <String, dynamic>{};
  final Map<String, RTCVideoRenderer> _remoteAudioRenderersByProducerId = <String, RTCVideoRenderer>{};

  final ValueNotifier<bool> connected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> joined = ValueNotifier<bool>(false);
  final ValueNotifier<bool> localMicCapturing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> audioPublishing = ValueNotifier<bool>(false);
  final ValueNotifier<int> remoteAudioCount = ValueNotifier<int>(0);
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
      <String, Object?>{'roomId': safeRoomId, 'peerId': safePeerId},
      onAck: (ack) {
        if (ack['ok'] == true) {
          _joined = true;
          joined.value = true;
          _routerRtpCapabilities = ack['rtpCapabilities'];
          seats.value = AudioSeatSnapshot.listFromJson(ack['room']?['seats']);
          _rememberProducers(ack['room']?['producers']);
          _debug('audio join ok room=$safeRoomId peer=$safePeerId');
          unawaited(_ensureDeviceLoaded().then((_) => _consumePendingProducers()));
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
          if (!_selfMuted) _produceRetryCount = 0;
          unawaited(_syncLocalMicCapture());
        }
      },
    );
  }

  void leaveSeat() {
    if (!_canSendRoomEvent()) return;
    _seated = false;
    _selfMuted = true;
    _cancelProduceRetry();
    unawaited(_stopPublishingAndCapture());
    _emitWithAck('leaveSeat', <String, Object?>{'roomId': _roomId, 'peerId': _peerId}, onAck: _handleSeatAck);
  }

  void setSelfMuted(bool muted) {
    if (!_canSendRoomEvent()) return;
    _selfMuted = muted;
    if (!muted) _produceRetryCount = 0;
    if (muted) _cancelProduceRetry();
    unawaited(_syncLocalMicCapture());
    _emitWithAck('setSelfMuted', <String, Object?>{'roomId': _roomId, 'peerId': _peerId, 'muted': muted}, onAck: _handleSeatAck);
  }

  Future<void> leaveRoom() async {
    _cancelProduceRetry();
    await _stopPublishingAndCapture();
    await _closeAllRemoteConsumers();
    _joined = false;
    _seated = false;
    _selfMuted = true;
    joined.value = false;
    seats.value = <AudioSeatSnapshot>[];
    _roomId = null;
    _peerId = null;
    _currentUser = null;
    _routerRtpCapabilities = null;
    _device = null;
    _pendingProducerIds.clear();
    _producerInfoById.clear();
    _closingRemoteProducerIds.clear();
    _closeSendTransport();
    _closeRecvTransport();
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
      io.OptionBuilder().setTransports(<String>['websocket']).disableAutoConnect().enableReconnection().setReconnectionAttempts(20).setReconnectionDelay(700).build(),
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
      _cancelProduceRetry();
      unawaited(_stopPublishingAndCapture());
      unawaited(_closeAllRemoteConsumers());
      _closeSendTransport();
      _closeRecvTransport();
      _debug('audio socket disconnected');
    });

    socket.onConnectError((dynamic error) => _setError('Audio socket connect error: $error'));
    socket.onError((dynamic error) => _setError('Audio socket error: $error'));

    socket.on('seatsUpdated', (dynamic payload) {
      if (payload is Map) {
        final nextSeats = AudioSeatSnapshot.listFromJson(payload['seats']);
        seats.value = nextSeats;
        _seated = nextSeats.any((seat) => seat.peerId == _peerId);
        if (!_seated) {
          _selfMuted = true;
          _cancelProduceRetry();
          unawaited(_stopPublishingAndCapture());
        }
        _debug('audio seats updated count=${seats.value.length} seated=$_seated');
      }
    });

    socket.on('peerJoined', (dynamic payload) => _debug('audio peer joined $payload'));
    socket.on('peerLeft', (dynamic payload) => _debug('audio peer left $payload'));

    socket.on('newProducer', (dynamic payload) {
      _debug('audio new producer $payload');
      final info = RemoteProducerInfo.fromPayload(payload);
      if (info == null || info.peerId == _peerId || info.kind != 'audio') return;
      _producerInfoById[info.producerId] = info;
      _pendingProducerIds.add(info.producerId);
      unawaited(_consumePendingProducers());
    });

    socket.on('producerClosed', (dynamic payload) {
      _debug('audio producer closed $payload');
      if (payload is Map) {
        final producerId = payload['producerId']?.toString();
        if (producerId != null && producerId.isNotEmpty) unawaited(_closeRemoteConsumer(producerId));
      }
    });

    _socket = socket;
    socket.connect();
    _connecting = false;
  }

  Future<void> _syncLocalMicCapture() async {
    if (_seated && !_selfMuted) {
      await _startLocalMicCapture();
      await _ensurePublishingAudio();
    } else {
      await _stopPublishingAndCapture();
    }
  }

  Future<void> _startLocalMicCapture() async {
    if (_localAudioStream != null) return;
    try {
      final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
        'audio': <String, dynamic>{'echoCancellation': true, 'noiseSuppression': true, 'autoGainControl': true},
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

  Future<void> _ensureDeviceLoaded() async {
    if (_device != null || _deviceLoading) return;
    final rawCaps = _routerRtpCapabilities;
    if (rawCaps == null) return;
    _deviceLoading = true;
    try {
      final caps = RtpCapabilities.fromMap(Map<String, dynamic>.from(rawCaps as Map));
      final device = Device();
      await device.load(routerRtpCapabilities: caps);
      _device = device;
      _debug('mediasoup device loaded');
    } catch (error) {
      _setError('Mediasoup device load failed: $error');
    } finally {
      _deviceLoading = false;
    }
  }

  Future<void> _ensureSendTransport() async {
    if (_sendTransport != null || _sendTransportCreating) return;
    if (!_canSendRoomEvent()) return;
    await _ensureDeviceLoaded();
    final device = _device;
    if (device == null) return;

    _sendTransportCreating = true;
    try {
      final ack = await _emitWithAckFuture('createWebRtcTransport', <String, Object?>{'roomId': _roomId, 'peerId': _peerId, 'direction': 'send'});
      if (ack['ok'] != true) throw Exception(ack['error'] ?? 'createWebRtcTransport failed');

      final params = Map<String, dynamic>.from(ack['params'] as Map);
      final transport = device.createSendTransportFromMap(
        params,
        producerCallback: (Producer producer) {
          _cancelProduceRetry();
          _produceRetryCount = 0;
          _audioProducer = producer;
          audioPublishing.value = true;
          _debug('audio producer callback id=${producer.id} kind=${producer.kind}');
        },
      );

      _bindTransportConnect(transport, label: 'send');

      transport.on('produce', (dynamic data) async {
        try {
          final produceAck = await _emitWithAckFuture('produce', <String, Object?>{
            'roomId': _roomId,
            'peerId': _peerId,
            'transportId': transport.id,
            'kind': data['kind'],
            'rtpParameters': _toPlainMap(data['rtpParameters']),
          });
          if (produceAck['ok'] == true) {
            final producerId = produceAck['producerId']?.toString() ?? produceAck['id']?.toString() ?? '';
            data['callback'](producerId);
            _debug('produce ack producer=$producerId');
          } else {
            data['errback'](produceAck['error'] ?? 'produce failed');
          }
        } catch (error) {
          data['errback'](error);
        }
      });

      transport.on('connectionstatechange', (dynamic state) {
        _debug('send transport state=$state');
        final stateText = state.toString().toLowerCase();
        if (stateText.contains('connected')) _scheduleProduceRetry('send transport connected');
      });

      _sendTransport = transport;
      _debug('send transport created id=${transport.id}');
    } catch (error) {
      _setError('Send transport create failed: $error');
    } finally {
      _sendTransportCreating = false;
    }
  }

  Future<void> _ensureRecvTransport() async {
    if (_recvTransport != null || _recvTransportCreating) return;
    if (!_canSendRoomEvent()) return;
    await _ensureDeviceLoaded();
    final device = _device;
    if (device == null) return;

    _recvTransportCreating = true;
    try {
      final ack = await _emitWithAckFuture('createWebRtcTransport', <String, Object?>{'roomId': _roomId, 'peerId': _peerId, 'direction': 'recv'});
      if (ack['ok'] != true) throw Exception(ack['error'] ?? 'create recv transport failed');

      final params = Map<String, dynamic>.from(ack['params'] as Map);
      final transport = device.createRecvTransportFromMap(
        params,
        consumerCallback: (Consumer consumer, dynamic _) => _attachRemoteConsumer(consumer),
      );

      _bindTransportConnect(transport, label: 'recv');
      transport.on('connectionstatechange', (dynamic state) => _debug('recv transport state=$state'));

      _recvTransport = transport;
      _debug('recv transport created id=${transport.id}');
    } catch (error) {
      _setError('Recv transport create failed: $error');
    } finally {
      _recvTransportCreating = false;
    }
  }

  void _bindTransportConnect(dynamic transport, {required String label}) {
    transport.on('connect', (dynamic data) async {
      try {
        final dtlsParameters = _toPlainMap(data['dtlsParameters']);
        final connectAck = await _emitWithAckFuture('connectTransport', <String, Object?>{
          'roomId': _roomId,
          'peerId': _peerId,
          'transportId': transport.id,
          'dtlsParameters': dtlsParameters,
        });
        if (connectAck['ok'] == true) {
          data['callback']();
          _debug('$label transport connected id=${transport.id}');
          if (label == 'send') _scheduleProduceRetry('send transport connect callback');
        } else {
          data['errback'](connectAck['error'] ?? 'connectTransport failed');
        }
      } catch (error) {
        data['errback'](error);
      }
    });
  }

  Future<void> _ensurePublishingAudio() async {
    if (_producerCreating || _audioProducer != null) return;
    if (!_seated || _selfMuted || _localAudioStream == null) return;
    _producerCreating = true;
    try {
      await _ensureSendTransport();
      final transport = _sendTransport;
      final stream = _localAudioStream;
      if (transport == null || stream == null) return;
      final audioTracks = stream.getAudioTracks();
      if (audioTracks.isEmpty) throw Exception('No local audio track available');
      final audioTrack = audioTracks.first;
      try {
        final maybeProducer = await transport.produce(
          source: 'mic',
          stream: stream,
          track: audioTrack,
          appData: <String, dynamic>{'mediaTag': 'mic-audio'},
        );
        if (maybeProducer != null) {
          _cancelProduceRetry();
          _produceRetryCount = 0;
          _audioProducer = maybeProducer;
          audioPublishing.value = true;
          _debug('audio publishing started producer=${maybeProducer.id}');
        }
      } catch (error, stackTrace) {
        final message = error.toString();
        if (message.contains('Null check operator used on a null value')) {
          _debug('audio produce startup race detected; scheduling automatic retry');
          _scheduleProduceRetry('initial produce race');
          return;
        }
        _debug('$error\n$stackTrace');
        rethrow;
      }
      _debug('audio produce requested');
      _scheduleProduceRetry('producer callback watchdog');
    } catch (error) {
      _setError('Audio produce failed: $error');
    } finally {
      _producerCreating = false;
    }
  }

  void _scheduleProduceRetry(String reason) {
    if (!_seated || _selfMuted || _localAudioStream == null || _audioProducer != null) return;
    if (_produceRetryTimer?.isActive ?? false) return;
    if (_produceRetryCount >= 3) {
      _debug('audio produce retry limit reached');
      return;
    }
    _produceRetryCount += 1;
    _debug('audio produce retry scheduled #$_produceRetryCount reason=$reason');
    _produceRetryTimer = Timer(Duration(milliseconds: 450 + (_produceRetryCount * 250)), () {
      _produceRetryTimer = null;
      if (!_seated || _selfMuted || _localAudioStream == null || _audioProducer != null) return;
      _debug('audio produce retry running #$_produceRetryCount');
      unawaited(_ensurePublishingAudio());
    });
  }

  void _cancelProduceRetry() {
    _produceRetryTimer?.cancel();
    _produceRetryTimer = null;
  }

  void _rememberProducers(dynamic rawProducers) {
    if (rawProducers is! List) return;
    for (final item in rawProducers) {
      final info = RemoteProducerInfo.fromPayload(item);
      if (info == null || info.peerId == _peerId || info.kind != 'audio') continue;
      _producerInfoById[info.producerId] = info;
      _pendingProducerIds.add(info.producerId);
    }
  }

  Future<void> _consumePendingProducers() async {
    if (_pendingProducerIds.isEmpty) return;
    await _ensureDeviceLoaded();
    await _ensureRecvTransport();
    final pending = List<String>.from(_pendingProducerIds);
    for (final producerId in pending) {
      await _consumeProducer(producerId);
    }
  }

  Future<void> _consumeProducer(String producerId) async {
    if (_remoteConsumersByProducerId.containsKey(producerId) || _consumingProducerIds.contains(producerId)) return;
    final transport = _recvTransport;
    final device = _device;
    final info = _producerInfoById[producerId];
    if (transport == null || device == null || info == null) return;

    _consumingProducerIds.add(producerId);
    try {
      final ack = await _emitWithAckFuture('consume', <String, Object?>{
        'roomId': _roomId,
        'peerId': _peerId,
        'transportId': transport.id,
        'producerId': producerId,
        'rtpCapabilities': device.rtpCapabilities.toMap(),
      });
      if (ack['ok'] != true) throw Exception(ack['error'] ?? 'consume failed');

      final params = Map<String, dynamic>.from(ack['params'] as Map);
      final rtpParameters = RtpParameters.fromMap(Map<String, dynamic>.from(params['rtpParameters'] as Map));
      final kind = (params['kind']?.toString() ?? 'audio') == 'audio' ? RTCRtpMediaType.RTCRtpMediaTypeAudio : RTCRtpMediaType.RTCRtpMediaTypeVideo;

      transport.consume(
        id: params['id']?.toString() ?? '',
        producerId: params['producerId']?.toString() ?? producerId,
        peerId: info.peerId,
        kind: kind,
        rtpParameters: rtpParameters,
        appData: <String, dynamic>{'producerId': producerId, 'peerId': info.peerId},
      );
      _pendingProducerIds.remove(producerId);
      _debug('consume requested producer=$producerId peer=${info.peerId}');
    } catch (error) {
      _setError('Consume failed for producer=$producerId: $error');
    } finally {
      _consumingProducerIds.remove(producerId);
    }
  }

  Future<void> _attachRemoteConsumer(Consumer consumer) async {
    try {
      final producerId = consumer.producerId;
      if (_remoteConsumersByProducerId.containsKey(producerId)) return;
      _remoteConsumersByProducerId[producerId] = consumer;

      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = consumer.stream;
      _remoteAudioRenderersByProducerId[producerId] = renderer;
      remoteAudioCount.value = _remoteConsumersByProducerId.length;

      consumer.on('transportclose', () => unawaited(_closeRemoteConsumer(producerId)));
      consumer.on('trackended', () => unawaited(_closeRemoteConsumer(producerId)));

      _debug('remote audio consumer attached producer=$producerId consumer=${consumer.id} track=${consumer.track.id}');
    } catch (error) {
      _setError('Remote consumer attach failed: $error');
    }
  }

  Future<void> _stopPublishingAndCapture() async {
    _cancelProduceRetry();
    await _stopAudioProducer();
    await _stopLocalMicCapture();
  }

  Future<void> _stopAudioProducer() async {
    final producer = _audioProducer;
    if (producer == null) return;
    _audioProducer = null;
    try {
      producer.close();
    } catch (_) {}
    audioPublishing.value = false;
    _debug('audio producer closed locally');
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

  void _closeSendTransport() {
    final transport = _sendTransport;
    _sendTransport = null;
    _cancelProduceRetry();
    try {
      transport?.close();
    } catch (_) {}
    _audioProducer = null;
    audioPublishing.value = false;
  }

  void _closeRecvTransport() {
    final transport = _recvTransport;
    _recvTransport = null;
    try {
      transport?.close();
    } catch (_) {}
  }

  Future<void> _closeRemoteConsumer(String producerId) async {
    if (_closingRemoteProducerIds.contains(producerId)) return;
    _closingRemoteProducerIds.add(producerId);
    final consumer = _remoteConsumersByProducerId.remove(producerId);
    final renderer = _remoteAudioRenderersByProducerId.remove(producerId);
    _pendingProducerIds.remove(producerId);
    _producerInfoById.remove(producerId);
    try {
      consumer?.close();
    } catch (_) {}
    try {
      renderer?.srcObject = null;
      await renderer?.dispose();
    } catch (_) {}
    remoteAudioCount.value = _remoteConsumersByProducerId.length;
    _closingRemoteProducerIds.remove(producerId);
    if (consumer != null || renderer != null) _debug('remote audio consumer closed producer=$producerId');
  }

  Future<void> _closeAllRemoteConsumers() async {
    final producerIds = List<String>.from(_remoteConsumersByProducerId.keys);
    for (final producerId in producerIds) {
      await _closeRemoteConsumer(producerId);
    }
    _pendingProducerIds.clear();
    _consumingProducerIds.clear();
  }

  Map<String, dynamic> _toPlainMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    final dynamicValue = value as dynamic;
    final mapped = dynamicValue.toMap();
    if (mapped is Map<String, dynamic>) return mapped;
    return Map<String, dynamic>.from(mapped as Map);
  }

  bool _canSendRoomEvent() => _socket?.connected == true && _joined && _roomId != null && _peerId != null;

  void _emitWithAck(String event, Map<String, Object?> payload, {required void Function(Map<String, dynamic> ack) onAck}) {
    final socket = _socket;
    if (socket == null) return;
    _debug('audio send $event $payload');
    socket.emitWithAck(event, payload, ack: (dynamic rawAck) {
      final ack = rawAck is Map ? Map<String, dynamic>.from(rawAck) : <String, dynamic>{'ok': false, 'error': 'Invalid ack'};
      onAck(ack);
    });
  }

  Future<Map<String, dynamic>> _emitWithAckFuture(String event, Map<String, Object?> payload) {
    final socket = _socket;
    if (socket == null) return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': false, 'error': 'Socket not connected'});
    final completer = Completer<Map<String, dynamic>>();
    _debug('audio send $event $payload');
    socket.emitWithAck(event, payload, ack: (dynamic rawAck) {
      if (completer.isCompleted) return;
      final ack = rawAck is Map ? Map<String, dynamic>.from(rawAck) : <String, dynamic>{'ok': false, 'error': 'Invalid ack'};
      completer.complete(ack);
    });
    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => <String, dynamic>{'ok': false, 'error': '$event timed out'});
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

class RemoteProducerInfo {
  const RemoteProducerInfo({required this.producerId, required this.peerId, required this.kind, this.seatNo});

  final String producerId;
  final String peerId;
  final String kind;
  final int? seatNo;

  static RemoteProducerInfo? fromPayload(dynamic payload) {
    if (payload is! Map) return null;
    final map = Map<String, dynamic>.from(payload);
    final producerId = map['producerId']?.toString();
    final peerId = map['peerId']?.toString();
    final kind = map['kind']?.toString() ?? 'audio';
    if (producerId == null || producerId.isEmpty || peerId == null || peerId.isEmpty) return null;
    return RemoteProducerInfo(producerId: producerId, peerId: peerId, kind: kind, seatNo: int.tryParse(map['seatNo']?.toString() ?? ''));
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
