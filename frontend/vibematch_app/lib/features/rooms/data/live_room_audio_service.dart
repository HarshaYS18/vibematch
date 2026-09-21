import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
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
  String? _serverAudioProducerId;
  Timer? _produceRetryTimer;
  Timer? _recoveryTimer;
  Timer? _activeSpeakerSilenceTimer;
  DateTime? _sendTransportWarmupUntil;
  int? _desiredSeatIndex;
  int _produceRetryCount = 0;
  bool _joined = false;
  bool _connecting = false;
  bool _selfMuted = true;
  bool _desiredSelfMuted = true;
  bool _seated = false;
  bool _shouldStayConnected = false;
  bool _deviceLoading = false;
  bool _sendTransportCreating = false;
  bool _recvTransportCreating = false;
  bool _producerCreating = false;
  bool _rebuildSendPipelineOnRetry = false;
  bool _recovering = false;
  bool _rediscovering = false;
  bool _joinInFlight = false;
  bool _consumePendingRunning = false;
  Future<void>? _recvTransportFuture;

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
  final ValueNotifier<List<RTCVideoRenderer>> remoteAudioRenderers =
      ValueNotifier<List<RTCVideoRenderer>>(<RTCVideoRenderer>[]);
  final ValueNotifier<List<AudioSeatSnapshot>> seats = ValueNotifier<List<AudioSeatSnapshot>>(<AudioSeatSnapshot>[]);
  final ValueNotifier<Set<String>> activeSpeakerPeerIds = ValueNotifier<Set<String>>(<String>{});
  final ValueNotifier<String?> lastError = ValueNotifier<String?>(null);

  bool get isJoined => _joined;
  String? get roomId => _roomId;
  String? get peerId => _peerId;

  Future<void> joinRoom({required String roomId, required SeatUser currentUser}) async {
    final safeRoomId = roomId.trim().isEmpty ? 'VM257808' : roomId.trim();
    final safePeerId = '${safeRoomId}_${currentUser.id}'.replaceAll(RegExp(r'[^a-zA-Z0-9_\\-]'), '_');

    _shouldStayConnected = true;
    _roomId = safeRoomId;
    _peerId = safePeerId;
    _currentUser = currentUser;

    if (_joined && _socket?.connected == true) {
      _debug('join skipped already joined room=$safeRoomId peer=$safePeerId');
      return;
    }

    await _connectIfNeeded();
    _sendJoinRoom();
  }

  void takeSeat(int seatIndex, {bool? micEnabled}) {
    if (seatIndex < 0) return;
    if (micEnabled != null) {
      _desiredSelfMuted = !micEnabled;
      _selfMuted = !micEnabled;
      if (_selfMuted) {
        _cancelProduceRetry();
        _removeActiveSpeaker(_peerId);
      } else {
        _produceRetryCount = 0;
      }
    }
    _desiredSeatIndex = seatIndex;
    _applyLocalSeatSnapshot(seatIndex);
    _seated = true;
    if (!_selfMuted) _produceRetryCount = 0;
    unawaited(_syncLocalMicCapture());
    // Seat ownership is authoritative in FastAPI room realtime. The audio
    // service only tracks local media intent; produce_audio is re-authorized
    // by FastAPI before mediasoup accepts a producer.
    if (!_canSendRoomEvent()) {
      _scheduleRecovery('takeSeat while disconnected');
    }
  }

  void leaveSeat() {
    _desiredSeatIndex = null;
    _clearActiveSpeakers();
    _clearLocalSeatSnapshot();
    _seated = false;
    _selfMuted = true;
    _desiredSelfMuted = true;
    _cancelProduceRetry();
    unawaited(_stopPublishingAndCapture());
  }

  void setSelfMuted(bool muted) {
    _desiredSelfMuted = muted;
    _selfMuted = muted;
    if (muted) _removeActiveSpeaker(_peerId);
    if (!muted) _produceRetryCount = 0;
    if (muted) _cancelProduceRetry();
    _applyLocalMuteSnapshot(muted);
    if (!_canSendRoomEvent()) {
      if (!muted) _scheduleRecovery('unmute while disconnected');
      return;
    }
    unawaited(_syncLocalMicCapture());
  }


  Future<bool> startRoomMusic({
    required String url,
    required String title,
    int seekMs = 0,
  }) async {
    final safeUrl = url.trim();
    if (safeUrl.isEmpty) {
      _setError('Room music URL is empty.');
      return false;
    }

    if (!_canSendRoomEvent()) {
      _scheduleRecovery('start room music while disconnected');
      _setError('Audio room is not connected yet. Try again after joining audio.');
      return false;
    }

    final ack = await _emitWithAckFuture('startRoomMusic', <String, Object?>{
      'roomId': _roomId,
      'peerId': _peerId,
      'url': safeUrl,
      'title': title.trim().isEmpty ? 'Room music' : title.trim(),
      'seekMs': seekMs < 0 ? 0 : seekMs,
    });

    if (ack['ok'] == true) {
      _debug('room music started: ${ack['music']}');
      return true;
    }

    _setError('Room music start failed: ${ack['error'] ?? 'unknown'}');
    return false;
  }

  Future<bool> stopRoomMusic() async {
    if (!_canSendRoomEvent()) return false;

    final ack = await _emitWithAckFuture('stopRoomMusic', <String, Object?>{
      'roomId': _roomId,
      'peerId': _peerId,
    });

    if (ack['ok'] == true) {
      _debug('room music stopped');
      return true;
    }

    _setError('Room music stop failed: ${ack['error'] ?? 'unknown'}');
    return false;
  }

  Future<void> recoverAfterForeground() async {
    _debug('audio foreground recovery requested');
    await _recoverSession('app foreground');
  }

  Future<void> leaveRoom() async {
    _shouldStayConnected = false;
    _desiredSeatIndex = null;
    _desiredSelfMuted = true;
    _recoveryTimer?.cancel();
    _recoveryTimer = null;
    _activeSpeakerSilenceTimer?.cancel();
    _activeSpeakerSilenceTimer = null;
    _cancelProduceRetry();
    await _stopPublishingAndCapture();
    await _closeAllRemoteConsumers();
    _joined = false;
    _joinInFlight = false;
    _seated = false;
    _selfMuted = true;
    joined.value = false;
    seats.value = <AudioSeatSnapshot>[];
    activeSpeakerPeerIds.value = <String>{};
    remoteAudioRenderers.value = <RTCVideoRenderer>[];
    _roomId = null;
    _peerId = null;
    _currentUser = null;
    _routerRtpCapabilities = null;
    _device = null;
    _pendingProducerIds.clear();
    _producerInfoById.clear();
    _closingRemoteProducerIds.clear();
    _rebuildSendPipelineOnRetry = false;
    _sendTransportWarmupUntil = null;
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

    final authApi = const AuthApiService();
    final accessToken = authApi.cachedAccessToken;
    if (accessToken == null || accessToken.trim().isEmpty) {
      _connecting = false;
      _setError('Audio socket auth failed: login token missing.');
      return;
    }

    final deviceId = await authApi.getCurrentDeviceId();

    late final String audioUrl;
    try {
      audioUrl = await _resolveAssignedMediaUrl(
        accessToken: accessToken,
        deviceId: deviceId,
      );
    } catch (error) {
      _connecting = false;
      _setError('Audio node discovery failed: $error');
      return;
    }

    final socket = io.io(
      audioUrl,
      io.OptionBuilder()
          .setTransports(<String>['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(700)
          .setReconnectionDelayMax(2500)
          .setAuth(<String, Object?>{
            'token': 'Bearer $accessToken',
            'deviceId': deviceId,
          })
          .build(),
    );

    socket.onConnect((_) {
      connected.value = true;
      _debug('audio socket connected $audioUrl');
      if (_shouldStayConnected && _roomId != null && _currentUser != null) {
        _sendJoinRoom();
      }
    });

    socket.onDisconnect((_) {
      connected.value = false;
      _joined = false;
      _joinInFlight = false;
      joined.value = false;
      _clearActiveSpeakers();
      _cancelProduceRetry();
      unawaited(_stopPublishingAndCapture());
      unawaited(_closeAllRemoteConsumers());
      _closeSendTransport();
      _closeRecvTransport();
      _debug('audio socket disconnected; desiredSeat=$_desiredSeatIndex desiredMuted=$_desiredSelfMuted');
      if (_shouldStayConnected) _scheduleRecovery('audio socket disconnected');
    });

    socket.onConnectError((dynamic error) {
      _setError('Audio socket connect error: $error');
      if (_shouldStayConnected) _scheduleRecovery('audio connect error');
    });
    socket.onError((dynamic error) => _setError('Audio socket error: $error'));

    socket.on('activeSpeakers', _handleActiveSpeakers);
    socket.on('peerJoined', (dynamic payload) => _debug('audio peer joined $payload'));
    socket.on('peerLeft', (dynamic payload) {
      _debug('audio peer left $payload');
      if (payload is Map) _removeActiveSpeaker(payload['peerId']?.toString());
    });

    socket.on('newProducer', (dynamic payload) {
      _debug('audio new producer $payload');
      final info = RemoteProducerInfo.fromPayload(payload);
      if (info == null || info.peerId == _peerId || info.kind != 'audio') return;
      _producerInfoById[info.producerId] = info;
      if (_remoteConsumersByProducerId.containsKey(info.producerId) ||
          _consumingProducerIds.contains(info.producerId) ||
          _pendingProducerIds.contains(info.producerId)) {
        _debug('consume skipped duplicate producer event producer=${info.producerId}');
        return;
      }
      _pendingProducerIds.add(info.producerId);
      unawaited(_consumePendingProducers());
    });

    socket.on('producerClosed', (dynamic payload) {
      _debug('audio producer closed $payload');
      if (payload is Map) {
        final producerId = payload['producerId']?.toString();
        final peerId = payload['peerId']?.toString();
        _removeActiveSpeaker(peerId);
        if (producerId != null && producerId.isNotEmpty) unawaited(_closeRemoteConsumer(producerId));
      }
    });

    _socket = socket;
    socket.connect();
    _connecting = false;
  }

  Future<String> _resolveAssignedMediaUrl({
    required String accessToken,
    String? deviceId,
  }) async {
    final roomId = _roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      throw StateError('Room id is required before media discovery.');
    }

    final endpoint = Uri.parse(
      VmApiConfig.endpoint('/rooms/${Uri.encodeComponent(roomId)}/media'),
    ).replace(
      queryParameters: <String, String>{
        if (deviceId != null && deviceId.trim().isNotEmpty)
          'device_id': deviceId.trim(),
      },
    );

    final response = await http.get(
      endpoint,
      headers: <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $accessToken',
      },
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Media discovery returned ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Media discovery returned an invalid response.');
    }

    final signalingUrl = decoded['signaling_url']?.toString().trim() ?? '';
    if (signalingUrl.isEmpty) {
      throw StateError('Media discovery did not return signaling_url.');
    }
    return signalingUrl;
  }

  void _sendJoinRoom() {
    final safeRoomId = _roomId;
    final safePeerId = _peerId;
    if (safeRoomId == null || safePeerId == null || _socket?.connected != true) return;
    if (_joined) {
      _debug('join skipped already joined room=$safeRoomId');
      return;
    }
    if (_joinInFlight) {
      _debug('join skipped because in flight room=$safeRoomId');
      return;
    }
    _joinInFlight = true;
    _debug('join requested room=$safeRoomId peer=$safePeerId');
    _emitWithAck(
      'joinRoom',
      <String, Object?>{'roomId': safeRoomId, 'roomPublicId': safeRoomId, 'peerId': safePeerId},
      onAck: (ack) {
        _joinInFlight = false;
        if (ack['ok'] == true) {
          _joined = true;
          joined.value = true;
          _routerRtpCapabilities = ack['rtpCapabilities'];
          seats.value = AudioSeatSnapshot.listFromJson(ack['room']?['seats']);
          _rememberProducers(ack['room']?['producers']);
          _debug('audio join ok room=$safeRoomId peer=$safePeerId');
          unawaited(_restoreDesiredAudioStateAfterJoin());
        } else {
          final error = ack['error']?.toString() ?? 'unknown';
          final statusCode = int.tryParse(ack['statusCode']?.toString() ?? '');
          _setError('Audio join failed: $error');
          if (statusCode == 409 || error.contains('assigned to a different media node')) {
            unawaited(_rediscoverAssignedMediaNode('media assignment changed'));
            return;
          }
          _scheduleRecovery('audio join failed');
        }
      },
    );
  }

  Future<void> _rediscoverAssignedMediaNode(String reason) async {
    if (_rediscovering || !_shouldStayConnected || _roomId == null || _currentUser == null) return;
    _rediscovering = true;
    try {
      _debug('audio media rediscovery running: $reason');
      final socket = _socket;
      _socket = null;
      socket?.dispose();
      connected.value = false;
      _joined = false;
      _joinInFlight = false;
      joined.value = false;
      _cancelProduceRetry();
      await _stopPublishingAndCapture();
      await _closeAllRemoteConsumers();
      _closeSendTransport();
      _closeRecvTransport();
      await _connectIfNeeded();
      if (_socket?.connected == true) _sendJoinRoom();
    } finally {
      _rediscovering = false;
    }
  }

  Future<void> _restoreDesiredAudioStateAfterJoin() async {
    await _ensureDeviceLoaded();
    await _consumePendingProducers();
    final desiredSeat = _desiredSeatIndex;
    if (desiredSeat != null) {
      _debug('restoring desired audio seat=$desiredSeat muted=$_desiredSelfMuted');
      takeSeat(desiredSeat, micEnabled: !_desiredSelfMuted);
    }
  }

  void _scheduleRecovery(String reason) {
    if (!_shouldStayConnected || _roomId == null || _currentUser == null) return;
    if (_recoveryTimer?.isActive ?? false) return;
    _debug('audio recovery scheduled: $reason');
    _recoveryTimer = Timer(const Duration(milliseconds: 900), () {
      _recoveryTimer = null;
      unawaited(_recoverSession(reason));
    });
  }

  Future<void> _recoverSession(String reason) async {
    if (!_shouldStayConnected || _roomId == null || _currentUser == null || _recovering) return;
    _recovering = true;
    try {
      _debug('audio recovery running: $reason');
      await _connectIfNeeded();
      if (_socket?.connected == true) _sendJoinRoom();
    } finally {
      _recovering = false;
    }
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

      final params = _transportParamsFromAck(ack);
      final transport = device.createSendTransportFromMap(
        params,
        producerCallback: (Producer producer) {
          _cancelProduceRetry();
          _produceRetryCount = 0;
          _rebuildSendPipelineOnRetry = false;
          _serverAudioProducerId ??= producer.id;
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
            if (producerId.isEmpty) {
              data['errback']('produce failed: missing producer id');
              return;
            }
            _serverAudioProducerId = producerId;
            _cancelProduceRetry();
            _produceRetryCount = 0;
            _rebuildSendPipelineOnRetry = false;
            audioPublishing.value = true;
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
      _sendTransportWarmupUntil = DateTime.now().add(const Duration(milliseconds: 1400));
      _debug('send transport created id=${transport.id}; warming up before produce');
    } catch (error) {
      _setError('Send transport create failed: $error');
    } finally {
      _sendTransportCreating = false;
    }
  }

  Future<void> _waitForSendTransportWarmup() async {
    final until = _sendTransportWarmupUntil;
    if (until == null) return;
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative || remaining == Duration.zero) return;
    _debug('waiting ${remaining.inMilliseconds}ms for send transport warmup');
    await Future<void>.delayed(remaining);
  }

  Future<void> _ensureRecvTransport() async {
    if (_recvTransport != null) {
      _debug('recv transport reuse id=${_recvTransport.id}');
      return;
    }
    final inFlight = _recvTransportFuture;
    if (inFlight != null) {
      _debug('recv transport create/reuse in-flight');
      await inFlight;
      return;
    }
    if (!_canSendRoomEvent()) return;
    await _ensureDeviceLoaded();
    final device = _device;
    if (device == null) return;

    final future = _createRecvTransport(device);
    _recvTransportFuture = future;
    try {
      await future;
    } finally {
      _recvTransportFuture = null;
    }
  }

  Future<void> _createRecvTransport(Device device) async {
    if (_recvTransport != null || _recvTransportCreating) return;
    _recvTransportCreating = true;
    try {
      final ack = await _emitWithAckFuture('createWebRtcTransport', <String, Object?>{'roomId': _roomId, 'peerId': _peerId, 'direction': 'recv'});
      if (ack['ok'] != true) throw Exception(ack['error'] ?? 'create recv transport failed');

      final params = _transportParamsFromAck(ack);
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
        final connectAck = await _emitWithAckFuture('connectWebRtcTransport', <String, Object?>{
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
    if (_producerCreating || _audioProducer != null || _serverAudioProducerId != null) return;
    if (!_seated || _selfMuted || _localAudioStream == null) return;
    _producerCreating = true;
    try {
      await _ensureSendTransport();
      await _waitForSendTransportWarmup();
      final transport = _sendTransport;
      final stream = _localAudioStream;
      if (transport == null || stream == null) return;
      if (!_seated || _selfMuted || _audioProducer != null || _serverAudioProducerId != null) return;
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
          _rebuildSendPipelineOnRetry = false;
          _serverAudioProducerId ??= maybeProducer.id;
          _audioProducer = maybeProducer;
          audioPublishing.value = true;
          _debug('audio publishing started producer=${maybeProducer.id}');
        }
      } catch (error, stackTrace) {
        final message = error.toString();
        if (_isRecoverableProduceStartupError(message)) {
          _debug('audio produce startup race detected; rebuilding send pipeline and retrying');
          _scheduleProduceRetry('recoverable produce error', rebuildPipeline: true);
          return;
        }
        _debug('$error\n$stackTrace');
        rethrow;
      }
      _debug('audio produce requested serverProducer=$_serverAudioProducerId localProducer=${_audioProducer?.id}');
      if (_serverAudioProducerId == null && _audioProducer == null) {
        _scheduleProduceRetry('producer callback watchdog', rebuildPipeline: true);
      }
    } catch (error) {
      if (_isRecoverableProduceStartupError(error.toString())) {
        _debug('audio produce recoverable outer error; rebuilding send pipeline and retrying');
        _scheduleProduceRetry('recoverable outer produce error', rebuildPipeline: true);
      } else {
        _setError('Audio produce failed: $error');
      }
    } finally {
      _producerCreating = false;
    }
  }

  bool _isRecoverableProduceStartupError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('null check operator used on a null value') || lower.contains('track is null') || lower.contains('addtransceiver');
  }

  void _scheduleProduceRetry(String reason, {bool rebuildPipeline = false}) {
    if (!_seated || _selfMuted || _localAudioStream == null || _audioProducer != null || _serverAudioProducerId != null) return;
    if (rebuildPipeline) _rebuildSendPipelineOnRetry = true;
    if (_produceRetryTimer?.isActive ?? false) return;
    if (_produceRetryCount >= 3) {
      _debug('audio produce retry limit reached');
      return;
    }
    _produceRetryCount += 1;
    _debug('audio produce retry scheduled #$_produceRetryCount reason=$reason rebuild=$_rebuildSendPipelineOnRetry');
    _produceRetryTimer = Timer(Duration(milliseconds: 700 + (_produceRetryCount * 400)), () {
      _produceRetryTimer = null;
      if (!_seated || _selfMuted || _audioProducer != null || _serverAudioProducerId != null) return;
      _debug('audio produce retry running #$_produceRetryCount rebuild=$_rebuildSendPipelineOnRetry');
      unawaited(_runProduceRetry());
    });
  }

  Future<void> _runProduceRetry() async {
    if (!_seated || _selfMuted || _audioProducer != null || _serverAudioProducerId != null) return;
    if (_rebuildSendPipelineOnRetry) {
      _rebuildSendPipelineOnRetry = false;
      _debug('audio produce retry rebuilding mic stream and send transport');
      _closeSendTransport();
      await _stopLocalMicCapture();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!_seated || _selfMuted) return;
      await _startLocalMicCapture();
    }
    if (!_seated || _selfMuted || _localAudioStream == null || _audioProducer != null || _serverAudioProducerId != null) return;
    await _ensurePublishingAudio();
  }

  void _cancelProduceRetry() {
    _produceRetryTimer?.cancel();
    _produceRetryTimer = null;
    _rebuildSendPipelineOnRetry = false;
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
    if (_consumePendingRunning) {
      _debug('consume pending skipped because loop is already running count=${_pendingProducerIds.length}');
      return;
    }
    _consumePendingRunning = true;
    try {
      await _ensureDeviceLoaded();
      await _ensureRecvTransport();
      final pending = List<String>.from(_pendingProducerIds);
      for (final producerId in pending) {
        await _consumeProducer(producerId);
      }
    } finally {
      _consumePendingRunning = false;
    }
  }

  Future<void> _consumeProducer(String producerId) async {
    if (_remoteConsumersByProducerId.containsKey(producerId) || _consumingProducerIds.contains(producerId)) {
      _debug('consume skipped duplicate producer=$producerId');
      _pendingProducerIds.remove(producerId);
      return;
    }
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

      final params = _consumerParamsFromAck(ack, producerId: producerId);
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
      if (_remoteConsumersByProducerId.containsKey(producerId)) {
        _debug('remote renderer attach skipped duplicate producer=$producerId consumer=${consumer.id}');
        try {
          consumer.close();
        } catch (_) {}
        return;
      }
      _remoteConsumersByProducerId[producerId] = consumer;

      try {
        consumer.track.enabled = true;
      } catch (error) {
        _debug('remote audio track enable failed producer=$producerId error=$error');
      }

      try {
        consumer.resume();
      } catch (error) {
        _debug('local consumer resume failed producer=$producerId error=$error');
      }

      if (!kIsWeb) {
        try {
          await Helper.setSpeakerphoneOn(true);
        } catch (error) {
          _debug('set speakerphone failed: $error');
        }
      }

      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      renderer.srcObject = consumer.stream;

      _remoteAudioRenderersByProducerId[producerId] = renderer;
      remoteAudioCount.value = _remoteConsumersByProducerId.length;
      remoteAudioRenderers.value =
          List<RTCVideoRenderer>.from(_remoteAudioRenderersByProducerId.values);
      _debug('remote renderer attached producer=$producerId count=${remoteAudioRenderers.value.length}');

      final resumeAck = await _emitWithAckFuture('resumeConsumer', <String, Object?>{
        'roomId': _roomId,
        'peerId': _peerId,
        'consumerId': consumer.id,
        'producerId': producerId,
      });

      if (resumeAck['ok'] != true) {
        _debug('server consumer resume failed producer=$producerId ack=$resumeAck');
      }

      consumer.on('transportclose', () => unawaited(_closeRemoteConsumer(producerId)));
      consumer.on('trackended', () => unawaited(_closeRemoteConsumer(producerId)));

      _debug(
        'remote audio consumer attached/resumed '
        'producer=$producerId '
        'consumer=${consumer.id} '
        'track=${consumer.track.id} '
        'enabled=${consumer.track.enabled} '
        'stream=${consumer.stream.id}',
      );
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
    final serverProducerId = _serverAudioProducerId;
    if (producer == null && serverProducerId == null) return;
    _audioProducer = null;
    _serverAudioProducerId = null;
    try {
      producer.close();
    } catch (_) {}
    if (serverProducerId != null && serverProducerId.isNotEmpty && _canSendRoomEvent()) {
      final ack = await _emitWithAckFuture('closeProducer', <String, Object?>{
        'roomId': _roomId,
        'peerId': _peerId,
        'producerId': serverProducerId,
      });
      if (ack['ok'] != true) _debug('server producer close failed producer=$serverProducerId ack=$ack');
    }
    audioPublishing.value = false;
    _removeActiveSpeaker(_peerId);
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
    _sendTransportWarmupUntil = null;
    _cancelProduceRetry();
    _serverAudioProducerId = null;
    try {
      transport?.close();
    } catch (_) {}
    _audioProducer = null;
    audioPublishing.value = false;
    _removeActiveSpeaker(_peerId);
  }

  void _closeRecvTransport() {
    final transport = _recvTransport;
    _recvTransport = null;
    _recvTransportFuture = null;
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
    final producerInfo = _producerInfoById.remove(producerId);
    _removeActiveSpeaker(producerInfo?.peerId);
    try {
      consumer?.close();
    } catch (_) {}
    try {
      renderer?.srcObject = null;
      await renderer?.dispose();
    } catch (_) {}
    remoteAudioCount.value = _remoteConsumersByProducerId.length;
    remoteAudioRenderers.value =
        List<RTCVideoRenderer>.from(_remoteAudioRenderersByProducerId.values);
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
    _clearActiveSpeakers();
  }

  void _handleActiveSpeakers(dynamic payload) {
    if (payload is! Map) return;
    final roomId = payload['roomId']?.toString() ?? payload['room_id']?.toString();
    if (roomId != null && _roomId != null && roomId != _roomId) return;

    final rawSpeakers = payload['speakers'];
    final next = <String>{};
    if (rawSpeakers is List) {
      for (final item in rawSpeakers) {
        if (item is! Map) continue;
        final peerId = item['peerId']?.toString() ?? item['peer_id']?.toString();
        if (peerId == null || peerId.isEmpty) continue;
        next.add(peerId);
      }
    }

    if (_setEquals(activeSpeakerPeerIds.value, next)) {
      _scheduleSpeakerSilenceFallback();
      return;
    }

    activeSpeakerPeerIds.value = next;
    _debug('active speakers=${next.join(',')}');
    _scheduleSpeakerSilenceFallback();
  }

  void _scheduleSpeakerSilenceFallback() {
    _activeSpeakerSilenceTimer?.cancel();
    if (activeSpeakerPeerIds.value.isEmpty) return;
    _activeSpeakerSilenceTimer = Timer(const Duration(milliseconds: 900), _clearActiveSpeakers);
  }

  void _clearActiveSpeakers() {
    _activeSpeakerSilenceTimer?.cancel();
    _activeSpeakerSilenceTimer = null;
    if (activeSpeakerPeerIds.value.isEmpty) return;
    activeSpeakerPeerIds.value = <String>{};
  }

  void _removeActiveSpeaker(String? peerId) {
    if (peerId == null || peerId.isEmpty || activeSpeakerPeerIds.value.isEmpty) return;
    final next = Set<String>.from(activeSpeakerPeerIds.value)..remove(peerId);
    if (_setEquals(activeSpeakerPeerIds.value, next)) return;
    activeSpeakerPeerIds.value = next;
  }

  bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
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
    var completed = false;
    socket.emitWithAck(event, payload, ack: (dynamic rawAck) {
      if (completed) return;
      completed = true;
      onAck(_normalizeAck(rawAck));
    });
    Timer(const Duration(seconds: 8), () {
      if (completed) return;
      completed = true;
      onAck(<String, dynamic>{'ok': false, 'error': '$event timed out'});
    });
  }

  Future<Map<String, dynamic>> _emitWithAckFuture(String event, Map<String, Object?> payload) {
    final socket = _socket;
    if (socket == null) return Future<Map<String, dynamic>>.value(<String, dynamic>{'ok': false, 'error': 'Socket not connected'});
    final completer = Completer<Map<String, dynamic>>();
    _debug('audio send $event $payload');
    socket.emitWithAck(event, payload, ack: (dynamic rawAck) {
      if (completer.isCompleted) return;
      completer.complete(_normalizeAck(rawAck));
    });
    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => <String, dynamic>{'ok': false, 'error': '$event timed out'});
  }

  Map<String, dynamic> _normalizeAck(dynamic rawAck) {
    if (rawAck is! Map) {
      return <String, dynamic>{'ok': false, 'error': 'Invalid ack'};
    }

    final ack = Map<String, dynamic>.from(rawAck);
    final data = ack['data'];
    if (data is Map) {
      final merged = <String, dynamic>{...Map<String, dynamic>.from(data), ...ack};
      merged.remove('data');
      return merged;
    }
    return ack;
  }

  Map<String, dynamic> _transportParamsFromAck(Map<String, dynamic> ack) {
    final params = ack['params'];
    if (params is Map) return Map<String, dynamic>.from(params);
    return Map<String, dynamic>.from(ack);
  }

  Map<String, dynamic> _consumerParamsFromAck(
    Map<String, dynamic> ack, {
    required String producerId,
  }) {
    final params = ack['params'];
    final raw = params is Map ? Map<String, dynamic>.from(params) : Map<String, dynamic>.from(ack);
    return <String, dynamic>{
      'id': raw['id'] ?? raw['consumerId'] ?? '',
      'producerId': raw['producerId'] ?? producerId,
      'kind': raw['kind'] ?? 'audio',
      'rtpParameters': raw['rtpParameters'],
    };
  }

  void _applyLocalSeatSnapshot(int seatIndex) {
    final seatNo = seatIndex + 1;
    final safePeerId = _peerId;
    if (safePeerId == null || safePeerId.isEmpty) return;

    final next = _normalizedSeatList();
    final updated = <AudioSeatSnapshot>[];
    var replaced = false;

    for (final seat in next) {
      if (seat.peerId == safePeerId) {
        updated.add(AudioSeatSnapshot(
          seatNo: seat.seatNo,
          selfMuted: true,
          adminMuted: seat.adminMuted,
          locked: seat.locked,
        ));
        continue;
      }

      if (seat.seatNo == seatNo) {
        updated.add(AudioSeatSnapshot(
          seatNo: seatNo,
          peerId: safePeerId,
          producerId: seat.producerId,
          selfMuted: _selfMuted,
          adminMuted: seat.adminMuted,
          locked: seat.locked,
        ));
        replaced = true;
        continue;
      }

      updated.add(seat);
    }

    if (!replaced) {
      updated.add(AudioSeatSnapshot(
        seatNo: seatNo,
        peerId: safePeerId,
        selfMuted: _selfMuted,
      ));
    }

    updated.sort((a, b) => a.seatNo.compareTo(b.seatNo));
    seats.value = updated;
  }

  void _clearLocalSeatSnapshot() {
    final safePeerId = _peerId;
    if (safePeerId == null || safePeerId.isEmpty) return;

    seats.value = _normalizedSeatList()
        .map((seat) {
          if (seat.peerId != safePeerId) return seat;
          return AudioSeatSnapshot(
            seatNo: seat.seatNo,
            selfMuted: true,
            adminMuted: seat.adminMuted,
            locked: seat.locked,
          );
        })
        .toList();
  }

  void _applyLocalMuteSnapshot(bool muted) {
    final safePeerId = _peerId;
    if (safePeerId == null || safePeerId.isEmpty) return;

    seats.value = _normalizedSeatList()
        .map((seat) {
          if (seat.peerId != safePeerId) return seat;
          return AudioSeatSnapshot(
            seatNo: seat.seatNo,
            peerId: seat.peerId,
            producerId: seat.producerId,
            selfMuted: muted,
            adminMuted: seat.adminMuted,
            locked: seat.locked,
          );
        })
        .toList();
  }

  List<AudioSeatSnapshot> _normalizedSeatList() {
    if (seats.value.isNotEmpty) return List<AudioSeatSnapshot>.from(seats.value);

    return List<AudioSeatSnapshot>.generate(
      12,
      (index) => AudioSeatSnapshot(seatNo: index + 1, selfMuted: true),
    );
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
