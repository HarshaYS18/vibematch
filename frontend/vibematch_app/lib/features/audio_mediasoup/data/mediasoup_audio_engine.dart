import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart' as ms;

import '../models/mediasoup_producer_state.dart';
import '../models/mediasoup_room_state.dart';
import 'mediasoup_local_mic_service.dart';
import 'mediasoup_socket_service.dart';

class MediasoupAudioEngine {
  MediasoupAudioEngine({
    required MediasoupSocketService socketService,
    required MediasoupLocalMicService micService,
  })  : _socketService = socketService,
        _micService = micService;

  final MediasoupSocketService _socketService;
  final MediasoupLocalMicService _micService;

  final StreamController<String> _logController = StreamController<String>.broadcast();
  final Map<String, ms.Consumer> _consumersByProducerId = <String, ms.Consumer>{};
  final Map<String, MediaStream> _remoteStreamsByProducerId = <String, MediaStream>{};

  ms.Device? _device;
  ms.Transport? _sendTransport;
  ms.Transport? _recvTransport;
  ms.Producer? _audioProducer;
  MediasoupRoomState? _roomState;

  bool _publishing = false;

  Stream<String> get logs => _logController.stream;
  bool get deviceLoaded => _device?.loaded ?? false;
  bool get publishing => _publishing;
  int get remoteConsumerCount => _consumersByProducerId.length;
  String? get localProducerId => _audioProducer?.id;

  Future<void> loadRoom(MediasoupRoomState roomState) async {
    final rtpCapabilities = roomState.rtpCapabilities;
    if (rtpCapabilities == null) {
      throw StateError('Missing router RTP capabilities. Join room before loading audio engine.');
    }

    final device = ms.Device();
    await device.load(
      routerRtpCapabilities: ms.RtpCapabilities.fromMap(rtpCapabilities),
    );

    _device = device;
    _roomState = roomState;
    _log('mediasoup device loaded');
  }

  Future<void> publishMic() async {
    if (_publishing) return;

    final device = _requireDevice();
    final stream = await _micService.startMic();
    final audioTracks = stream.getAudioTracks();

    if (audioTracks.isEmpty) {
      throw StateError('No local audio track found. Check microphone permission.');
    }

    final transport = await _ensureSendTransport();
    final completer = Completer<ms.Producer>();

    transport.producerCallback = (dynamic producer) {
      if (producer is ms.Producer && !completer.isCompleted) {
        completer.complete(producer);
      }
    };

    final canProduceAudio = device.canProduce(ms.RTCRtpMediaType.RTCRtpMediaTypeAudio);
    if (!canProduceAudio) {
      throw StateError('This device cannot produce audio for the router capabilities.');
    }

    transport.produce(
      track: audioTracks.first,
      stream: stream,
      stopTracks: false,
      disableTrackOnPause: true,
      zeroRtpOnPause: false,
      codecOptions: ms.ProducerCodecOptions(
        opusFec: 1,
        opusDtx: 1,
        opusMaxAverageBitrate: 32000,
        opusPtime: 20,
      ),
      appData: <String, dynamic>{
        'source': 'vibematch_mic',
      },
      source: 'mic',
    );

    _audioProducer = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Timed out while creating audio producer'),
    );

    _publishing = true;
    _log('publishing mic producer=${_audioProducer!.id}');
  }

  Future<void> consumeExistingProducers(List<MediasoupProducerState> producers) async {
    for (final producer in producers) {
      await consumeProducer(producer);
    }
  }

  Future<void> consumeProducer(MediasoupProducerState producer) async {
    if (producer.producerId.isEmpty) return;
    if (_consumersByProducerId.containsKey(producer.producerId)) return;
    if (producer.peerId == _socketService.peerId) return;

    final device = _requireDevice();
    final transport = await _ensureRecvTransport();

    final response = await _socketService.consume(
      producerId: producer.producerId,
      transportId: transport.id,
      rtpCapabilities: device.rtpCapabilities.toMap(),
    );

    final params = (response['params'] as Map?)?.cast<String, dynamic>();
    if (params == null) {
      throw StateError('Missing consume params for producer ${producer.producerId}');
    }

    final completer = Completer<ms.Consumer>();

    transport.consumerCallback = (dynamic consumer, dynamic accept) {
      if (consumer is ms.Consumer && !completer.isCompleted) {
        if (accept is Function) {
          accept();
        }
        completer.complete(consumer);
      }
    };

    transport.consume(
      id: params['id']?.toString() ?? '',
      producerId: params['producerId']?.toString() ?? producer.producerId,
      peerId: producer.peerId,
      kind: _kindFromString(params['kind']?.toString() ?? 'audio'),
      rtpParameters: ms.RtpParameters.fromMap(
        (params['rtpParameters'] as Map).cast<String, dynamic>(),
      ),
      appData: <String, dynamic>{
        'sourcePeerId': producer.peerId,
        'seatNo': producer.seatNo,
      },
    );

    final consumer = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Timed out while consuming producer ${producer.producerId}'),
    );

    _consumersByProducerId[producer.producerId] = consumer;
    _remoteStreamsByProducerId[producer.producerId] = consumer.stream;
    _log('consuming peer=${producer.peerId} producer=${producer.producerId}');
  }

  Future<void> closeConsumer(String producerId) async {
    final consumer = _consumersByProducerId.remove(producerId);
    final stream = _remoteStreamsByProducerId.remove(producerId);

    if (consumer != null) {
      await consumer.close();
    }

    if (stream != null) {
      await stream.dispose();
    }

    _log('consumer closed producer=$producerId');
  }

  Future<void> setMuted(bool muted) async {
    _micService.setMuted(muted);

    final producer = _audioProducer;
    if (producer == null || producer.closed) return;

    if (muted) {
      producer.pause();
    } else {
      producer.resume();
    }
  }

  Future<void> stopPublishing() async {
    final producer = _audioProducer;
    _audioProducer = null;
    _publishing = false;

    if (producer != null && !producer.closed) {
      producer.close();
    }

    _log('local publishing stopped');
  }

  Future<void> close() async {
    await stopPublishing();

    for (final producerId in List<String>.from(_consumersByProducerId.keys)) {
      await closeConsumer(producerId);
    }

    final sendTransport = _sendTransport;
    final recvTransport = _recvTransport;
    _sendTransport = null;
    _recvTransport = null;
    _device = null;
    _roomState = null;

    if (sendTransport != null && !sendTransport.closed) {
      await sendTransport.close();
    }

    if (recvTransport != null && !recvTransport.closed) {
      await recvTransport.close();
    }

    _log('audio engine closed');
  }

  void dispose() {
    close();
    _logController.close();
  }

  Future<ms.Transport> _ensureSendTransport() async {
    final existing = _sendTransport;
    if (existing != null && !existing.closed) return existing;

    final response = await _socketService.createTransport(direction: 'send');
    final params = _extractTransportParams(response);
    final device = _requireDevice();

    final transport = device.createSendTransportFromMap(
      params,
      producerCallback: (dynamic producer) {
        if (producer is ms.Producer) {
          _audioProducer = producer;
        }
      },
    );

    _wireTransportEvents(transport);
    _sendTransport = transport;
    _log('send transport created id=${transport.id}');
    return transport;
  }

  Future<ms.Transport> _ensureRecvTransport() async {
    final existing = _recvTransport;
    if (existing != null && !existing.closed) return existing;

    final response = await _socketService.createTransport(direction: 'recv');
    final params = _extractTransportParams(response);
    final device = _requireDevice();

    final transport = device.createRecvTransportFromMap(params);

    _wireTransportEvents(transport);
    _recvTransport = transport;
    _log('recv transport created id=${transport.id}');
    return transport;
  }

  void _wireTransportEvents(ms.Transport transport) {
    transport.on('connect', (dynamic data) async {
      final map = _asMap(data);
      final callback = map['callback'];
      final errback = map['errback'];
      final dtlsParameters = map['dtlsParameters'];

      try {
        final dtlsMap = dtlsParameters is ms.DtlsParameters
            ? dtlsParameters.toMap()
            : _asMap(dtlsParameters);

        await _socketService.connectTransport(
          transportId: transport.id,
          dtlsParameters: dtlsMap,
        );

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
        final rtpMap = rtpParameters is ms.RtpParameters
            ? rtpParameters.toMap()
            : _asMap(rtpParameters);

        final response = await _socketService.produce(
          transportId: transport.id,
          kind: kind,
          rtpParameters: rtpMap,
        );

        final producerId = response['producerId']?.toString();
        if (producerId == null || producerId.isEmpty) {
          throw StateError('Server did not return producerId');
        }

        if (callback is Function) callback(producerId);
      } catch (error) {
        if (errback is Function) {
          errback(error);
        } else {
          rethrow;
        }
      }
    });

    transport.on('connectionstatechange', (dynamic data) {
      final state = _asMap(data)['connectionState']?.toString() ?? 'unknown';
      _log('transport ${transport.id} state=$state');
    });
  }

  Map<String, dynamic> _extractTransportParams(Map<String, dynamic> response) {
    final params = response['params'];
    if (params is Map<String, dynamic>) return params;
    if (params is Map) return params.cast<String, dynamic>();
    throw StateError('Missing transport params');
  }

  ms.Device _requireDevice() {
    final device = _device;
    if (device == null || !device.loaded) {
      throw StateError('mediasoup device is not loaded');
    }
    return device;
  }

  ms.RTCRtpMediaType _kindFromString(String value) {
    switch (value) {
      case 'audio':
        return ms.RTCRtpMediaType.RTCRtpMediaTypeAudio;
      case 'video':
        return ms.RTCRtpMediaType.RTCRtpMediaTypeVideo;
      default:
        return ms.RTCRtpMediaType.RTCRtpMediaTypeAudio;
    }
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
