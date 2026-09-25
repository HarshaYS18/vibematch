import 'dart:async';
import 'dart:convert';
import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart' as ms;

import '../../../core/network/vm_api_config.dart';
import '../../../foundation/runtime/media_resource_lifecycle.dart';
import '../../auth/data/auth_api_service.dart';
import '../../audio_mediasoup/data/mediasoup_socket_service.dart';
import '../../audio_mediasoup/models/mediasoup_producer_state.dart';
import '../../audio_mediasoup/models/mediasoup_room_state.dart';
import '../models/inbox_call_models.dart';
import 'runtime/camera_input_resource_participant.dart';

class InboxRemoteVideoStream {
  const InboxRemoteVideoStream({
    required this.producerId,
    required this.peerId,
    required this.stream,
  });

  final String producerId;
  final String peerId;
  final MediaStream stream;
}

class InboxCallMediaBridge {
  InboxCallMediaBridge({
    MediasoupSocketService? socketService,
    MediaResourceRegistry? resourceRegistry,
  }) : _socketService = socketService ?? MediasoupSocketService(),
       _resourceRegistry = resourceRegistry;

  final MediasoupSocketService _socketService;
  final MediaResourceRegistry? _resourceRegistry;
  CameraInputResourceParticipant? _cameraResourceParticipant;
  final StreamController<String> _logController = StreamController<String>.broadcast();
  final ValueNotifier<MediaStream?> localVideoStream = ValueNotifier<MediaStream?>(null);
  final ValueNotifier<List<InboxRemoteVideoStream>> remoteVideoStreams = ValueNotifier<List<InboxRemoteVideoStream>>(const <InboxRemoteVideoStream>[]);

  final Map<String, ms.Consumer> _consumersByProducerId = <String, ms.Consumer>{};
  final Map<String, MediaStream> _remoteStreamsByProducerId = <String, MediaStream>{};
  final Map<String, String> _remoteKindsByProducerId = <String, String>{};

  ms.Device? _device;
  ms.Transport? _sendTransport;
  ms.Transport? _recvTransport;
  ms.Producer? _audioProducer;
  ms.Producer? _videoProducer;
  MediaStream? _localStream;
  InboxCallSession? _joinedSession;
  bool _joining = false;
  String? _lastError;
  StreamSubscription<MediasoupProducerState>? _newProducerSub;
  StreamSubscription<String>? _producerClosedSub;

  bool get connected => _socketService.connected;
  bool get publishing => _audioProducer != null || _videoProducer != null;
  bool get publishingVideo => _videoProducer != null;
  bool get joining => _joining;
  String? get lastError => _lastError;
  Stream<String> get logs => _logController.stream;

  Future<void> joinAndPublish(InboxCallSession session) async {
    if (_joining) return;
    if (_joinedSession?.id == session.id && connected && publishing) return;
    final roomId = session.roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      throw StateError('Call media room is missing.');
    }

    _joining = true;
    _lastError = null;
    try {
      await leave();
      final peerId = _peerIdFor(session);
      final token = const AuthApiService().cachedAccessToken;
      if (token == null || token.isEmpty) throw StateError('Please log in again.');
      final discovery = await http.get(
        Uri.parse(VmApiConfig.endpoint('/rooms/${Uri.encodeComponent(roomId)}/media')),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (discovery.statusCode != 200) throw StateError('Call media is unavailable (${discovery.statusCode}).');
      final node = jsonDecode(discovery.body) as Map<String, dynamic>;
      final roomState = await _socketService.connectAndJoin(
        serverUrl: node['signaling_url'] as String, roomId: roomId,
        peerId: peerId, audioToken: token,
      );
      await _loadDevice(roomState);
      await _startLocalMedia(session);
      await _publishLocalTracks(session);
      await _consumeExistingProducers(roomState.producers);
      _newProducerSub = _socketService.newProducers.listen((producer) => unawaited(_consumeProducer(producer)));
      _producerClosedSub = _socketService.producerClosedEvents.listen((producerId) => unawaited(_closeConsumer(producerId)));
      _joinedSession = session;
      _log(session.isVideo ? 'video call media ready' : 'voice call media ready');
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _joining = false;
    }
  }

  Future<void> setMuted(bool muted) async {
    final tracks = _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      track.enabled = !muted;
    }
    final producer = _audioProducer;
    if (producer == null || producer.closed) return;
    muted ? producer.pause() : producer.resume();
    if (_socketService.connected) await _socketService.setProducerPaused(producer.id, muted);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      track.enabled = enabled;
    }
    final producer = _videoProducer;
    if (producer == null || producer.closed) return;
    enabled ? producer.resume() : producer.pause();
    if (_socketService.connected) await _socketService.setProducerPaused(producer.id, !enabled);
  }

  Future<void> switchCamera() async {
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  Future<void> leave() async {
    _detachCameraResource();
    _joinedSession = null;
    await _newProducerSub?.cancel();
    await _producerClosedSub?.cancel();
    _newProducerSub = null;
    _producerClosedSub = null;

    final audioProducer = _audioProducer;
    final videoProducer = _videoProducer;
    _audioProducer = null;
    _videoProducer = null;
    if (audioProducer != null && !audioProducer.closed) audioProducer.close();
    if (videoProducer != null && !videoProducer.closed) videoProducer.close();

    for (final producerId in List<String>.from(_consumersByProducerId.keys)) {
      await _closeConsumer(producerId);
    }

    final sendTransport = _sendTransport;
    final recvTransport = _recvTransport;
    _sendTransport = null;
    _recvTransport = null;
    _device = null;

    if (sendTransport != null && !sendTransport.closed) await sendTransport.close();
    if (recvTransport != null && !recvTransport.closed) await recvTransport.close();

    final stream = _localStream;
    _localStream = null;
    localVideoStream.value = null;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        await track.stop();
      }
      await stream.dispose();
    }

    await _socketService.disconnect();
  }

  Future<void> dispose() async {
    await leave();
    localVideoStream.dispose();
    remoteVideoStreams.dispose();
    _socketService.dispose();
    await _logController.close();
  }

  Future<void> _loadDevice(MediasoupRoomState roomState) async {
    final rtpCapabilities = roomState.rtpCapabilities;
    if (rtpCapabilities == null) throw StateError('Missing media router capabilities.');
    final device = ms.Device();
    await device.load(routerRtpCapabilities: ms.RtpCapabilities.fromMap(rtpCapabilities));
    _device = device;
  }

  Future<void> _startLocalMedia(InboxCallSession session) async {
    final stream = await navigator.mediaDevices.getUserMedia(<String, dynamic>{
      'audio': <String, dynamic>{
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': session.isVideo
          ? <String, dynamic>{
              'facingMode': 'user',
              'width': <String, dynamic>{'ideal': 720},
              'height': <String, dynamic>{'ideal': 1280},
              'frameRate': <String, dynamic>{'ideal': 24, 'max': 30},
            }
          : false,
    });
    _localStream = stream;
    localVideoStream.value = session.isVideo ? stream : null;
    if (session.isVideo && stream.getVideoTracks().isNotEmpty) {
      await _attachCameraResource(session);
    }
  }

  Future<void> _attachCameraResource(InboxCallSession session) async {
    if (_cameraResourceParticipant != null) return;
    final registry = _resourceRegistry;
    if (registry == null) return;

    final participant = CameraInputResourceParticipant(
      resourceId: 'camera-input:${session.id}',
      pauseCamera: _pauseCameraForLifecycle,
      resumeCamera: _resumeCameraForLifecycle,
      releaseCamera: _releaseCameraForSession,
    );
    try {
      if (!registry.register(participant)) return;
      _cameraResourceParticipant = participant;
      await participant.onForegroundChanged(registry.isForeground);
    } catch (_) {
      registry.unregister(
        participant.resourceId,
        expectedParticipant: participant,
      );
    }
  }

  void _detachCameraResource() {
    final registry = _resourceRegistry;
    final participant = _cameraResourceParticipant;
    _cameraResourceParticipant = null;
    if (registry == null || participant == null) return;
    registry.unregister(
      participant.resourceId,
      expectedParticipant: participant,
    );
  }

  Future<bool> _pauseCameraForLifecycle() async {
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    final wasEnabled = tracks.any((track) => track.enabled);
    if (wasEnabled) await setCameraEnabled(false);
    return wasEnabled;
  }

  Future<void> _resumeCameraForLifecycle() async {
    final session = _joinedSession;
    if (session == null || !session.isVideo) return;
    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    await setCameraEnabled(true);
  }

  Future<void> _releaseCameraForSession() async {
    final producer = _videoProducer;
    _videoProducer = null;
    if (producer != null && !producer.closed) producer.close();

    final tracks = _localStream?.getVideoTracks() ?? const <MediaStreamTrack>[];
    for (final track in tracks) {
      try {
        track.enabled = false;
        await track.stop();
      } catch (_) {}
    }
    localVideoStream.value = null;
  }

  Future<void> _publishLocalTracks(InboxCallSession session) async {
    final stream = _localStream;
    if (stream == null) throw StateError('Local media stream is not ready.');
    final device = _requireDevice();
    final transport = await _ensureSendTransport();

    final audioTracks = stream.getAudioTracks();
    if (audioTracks.isNotEmpty && device.canProduce(ms.RTCRtpMediaType.RTCRtpMediaTypeAudio)) {
      _audioProducer = await _produceTrack(
        transport: transport,
        track: audioTracks.first,
        stream: stream,
        source: 'mic',
        appData: const <String, dynamic>{'source': 'inbox_call_mic'},
        codecOptions: ms.ProducerCodecOptions(opusFec: 1, opusDtx: 1, opusMaxAverageBitrate: 32000, opusPtime: 20),
      );
    }

    final videoTracks = stream.getVideoTracks();
    if (session.isVideo && videoTracks.isNotEmpty && device.canProduce(ms.RTCRtpMediaType.RTCRtpMediaTypeVideo)) {
      _videoProducer = await _produceTrack(
        transport: transport,
        track: videoTracks.first,
        stream: stream,
        source: 'camera',
        appData: const <String, dynamic>{'source': 'inbox_call_camera'},
      );
    }
  }

  Future<ms.Producer> _produceTrack({
    required ms.Transport transport,
    required MediaStreamTrack track,
    required MediaStream stream,
    required String source,
    Map<String, dynamic> appData = const <String, dynamic>{},
    ms.ProducerCodecOptions? codecOptions,
  }) async {
    final completer = Completer<ms.Producer>();
    transport.producerCallback = (dynamic producer) {
      if (producer is ms.Producer && !completer.isCompleted) completer.complete(producer);
    };
    transport.produce(
      track: track,
      stream: stream,
      stopTracks: false,
      disableTrackOnPause: true,
      zeroRtpOnPause: false,
      codecOptions: codecOptions,
      appData: appData,
      source: source,
    );
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Timed out while publishing $source'));
  }

  Future<void> _consumeExistingProducers(List<MediasoupProducerState> producers) async {
    for (final producer in producers) {
      await _consumeProducer(producer);
    }
  }

  Future<void> _consumeProducer(MediasoupProducerState producer) async {
    if (producer.producerId.isEmpty) return;
    if (_consumersByProducerId.containsKey(producer.producerId)) return;
    if (producer.peerId == _socketService.peerId) return;

    final device = _requireDevice();
    final transport = await _ensureRecvTransport();
    final response = await _socketService.consume(producerId: producer.producerId, transportId: transport.id, rtpCapabilities: device.rtpCapabilities.toMap());
    final params = (response['params'] as Map?)?.cast<String, dynamic>();
    if (params == null) throw StateError('Missing consume params for producer ${producer.producerId}');

    final completer = Completer<ms.Consumer>();
    transport.consumerCallback = (dynamic consumer, dynamic accept) {
      if (consumer is ms.Consumer && !completer.isCompleted) {
        if (accept is Function) accept();
        completer.complete(consumer);
      }
    };

    final kind = params['kind']?.toString() ?? producer.kind;
    transport.consume(
      id: params['id']?.toString() ?? '',
      producerId: params['producerId']?.toString() ?? producer.producerId,
      peerId: producer.peerId,
      kind: _kindFromString(kind),
      rtpParameters: ms.RtpParameters.fromMap((params['rtpParameters'] as Map).cast<String, dynamic>()),
      appData: <String, dynamic>{'sourcePeerId': producer.peerId, 'kind': kind},
    );

    final consumer = await completer.future.timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Timed out while consuming ${producer.producerId}'));
    await _socketService.resumeConsumer(consumer.id);
    _consumersByProducerId[producer.producerId] = consumer;
    _remoteStreamsByProducerId[producer.producerId] = consumer.stream;
    _remoteKindsByProducerId[producer.producerId] = kind;
    if (kind == 'video') _publishRemoteVideoStreams();
  }

  Future<void> _closeConsumer(String producerId) async {
    final consumer = _consumersByProducerId.remove(producerId);
    final stream = _remoteStreamsByProducerId.remove(producerId);
    _remoteKindsByProducerId.remove(producerId);
    if (consumer != null && !consumer.closed) await consumer.close();
    if (stream != null) await stream.dispose();
    _publishRemoteVideoStreams();
  }

  void _publishRemoteVideoStreams() {
    final items = <InboxRemoteVideoStream>[];
    _remoteStreamsByProducerId.forEach((producerId, stream) {
      if (_remoteKindsByProducerId[producerId] == 'video') {
        final consumer = _consumersByProducerId[producerId];
        items.add(InboxRemoteVideoStream(producerId: producerId, peerId: consumer?.peerId ?? 'peer', stream: stream));
      }
    });
    remoteVideoStreams.value = List<InboxRemoteVideoStream>.unmodifiable(items);
  }

  Future<ms.Transport> _ensureSendTransport() async {
    final existing = _sendTransport;
    if (existing != null && !existing.closed) return existing;
    final response = await _socketService.createTransport(direction: 'send');
    final params = _extractTransportParams(response);
    final transport = _requireDevice().createSendTransportFromMap(params);
    _wireTransportEvents(transport);
    _sendTransport = transport;
    return transport;
  }

  Future<ms.Transport> _ensureRecvTransport() async {
    final existing = _recvTransport;
    if (existing != null && !existing.closed) return existing;
    final response = await _socketService.createTransport(direction: 'recv');
    final params = _extractTransportParams(response);
    final transport = _requireDevice().createRecvTransportFromMap(params);
    _wireTransportEvents(transport);
    _recvTransport = transport;
    return transport;
  }

  void _wireTransportEvents(ms.Transport transport) {
    transport.on('connect', (dynamic data) async {
      final map = _asMap(data);
      final callback = map['callback'];
      final errback = map['errback'];
      final dtlsParameters = map['dtlsParameters'];
      try {
        final dtlsMap = dtlsParameters is ms.DtlsParameters ? dtlsParameters.toMap() : _asMap(dtlsParameters);
        await _socketService.connectTransport(transportId: transport.id, dtlsParameters: dtlsMap);
        if (callback is Function) callback();
      } catch (error) {
        if (errback is Function) {
          errback(error);
        } else {
          rethrow;
        }
      }
    });

    transport.on('produce', (dynamic data) async {
      final map = _asMap(data);
      final callback = map['callback'];
      final errback = map['errback'];
      final kind = map['kind']?.toString() ?? 'audio';
      final rtpParameters = map['rtpParameters'];
      try {
        final rtpMap = rtpParameters is ms.RtpParameters ? rtpParameters.toMap() : _asMap(rtpParameters);
        final response = await _socketService.produce(transportId: transport.id, kind: kind, rtpParameters: rtpMap);
        final producerId = response['producerId']?.toString();
        if (producerId == null || producerId.isEmpty) throw StateError('Server did not return producerId');
        if (callback is Function) callback(producerId);
      } catch (error) {
        if (errback is Function) {
          errback(error);
        } else {
          rethrow;
        }
      }
    });
  }

  Map<String, dynamic> _extractTransportParams(Map<String, dynamic> response) {
    final params = response['params'];
    if (params is Map<String, dynamic>) return params;
    if (params is Map) return params.cast<String, dynamic>();
    if (response['id'] != null) return response;
    throw StateError('Missing transport params');
  }

  ms.Device _requireDevice() {
    final device = _device;
    if (device == null || !device.loaded) throw StateError('Media device is not ready');
    return device;
  }

  ms.RTCRtpMediaType _kindFromString(String value) {
    return value == 'video' ? ms.RTCRtpMediaType.RTCRtpMediaTypeVideo : ms.RTCRtpMediaType.RTCRtpMediaTypeAudio;
  }

  String _peerIdFor(InboxCallSession session) {
    final direction = session.direction.name;
    final safeCallId = session.id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return 'inbox_${safeCallId}_$direction';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  void _log(String message) {
    _logController.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
  }
}
