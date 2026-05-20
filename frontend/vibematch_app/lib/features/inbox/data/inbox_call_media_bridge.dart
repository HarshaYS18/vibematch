import '../../../core/network/vm_media_config.dart';
import '../../audio_mediasoup/data/mediasoup_audio_engine.dart';
import '../../audio_mediasoup/data/mediasoup_local_mic_service.dart';
import '../../audio_mediasoup/data/mediasoup_socket_service.dart';
import '../models/inbox_call_models.dart';

class InboxCallMediaBridge {
  InboxCallMediaBridge({
    MediasoupSocketService? socketService,
    MediasoupLocalMicService? micService,
  })  : _socketService = socketService ?? MediasoupSocketService(),
        _micService = micService ?? MediasoupLocalMicService() {
    _engine = MediasoupAudioEngine(
      socketService: _socketService,
      micService: _micService,
    );
  }

  late final MediasoupAudioEngine _engine;
  final MediasoupSocketService _socketService;
  final MediasoupLocalMicService _micService;

  InboxCallSession? _joinedSession;
  bool _joining = false;
  String? _lastError;

  bool get connected => _socketService.connected;
  bool get publishing => _engine.publishing;
  bool get joining => _joining;
  String? get lastError => _lastError;
  Stream<String> get logs => _engine.logs;

  Future<void> joinAndPublish(InboxCallSession session) async {
    if (_joining) return;
    if (_joinedSession?.id == session.id && connected && publishing) return;
    final roomId = session.roomId;
    if (roomId == null || roomId.trim().isEmpty) {
      throw StateError('Inbox call is missing mediasoup room id.');
    }

    _joining = true;
    _lastError = null;
    try {
      await leave();
      final peerId = _peerIdFor(session);
      final roomState = await _socketService.connectAndJoin(
        serverUrl: VmMediaConfig.audioUrl,
        roomId: roomId,
        peerId: peerId,
      );
      await _engine.loadRoom(roomState);
      await _engine.publishMic();
      await _engine.consumeExistingProducers(roomState.producers);
      _socketService.newProducers.listen((producer) {
        _engine.consumeProducer(producer);
      });
      _socketService.producerClosedEvents.listen((producerId) {
        _engine.closeConsumer(producerId);
      });
      _joinedSession = session;
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _joining = false;
    }
  }

  Future<void> setMuted(bool muted) async {
    await _engine.setMuted(muted);
    if (_socketService.connected) {
      await _socketService.setSelfMuted(muted);
    }
  }

  Future<void> leave() async {
    _joinedSession = null;
    await _engine.close();
    await _micService.stopMic();
    await _socketService.disconnect();
  }

  Future<void> dispose() async {
    await leave();
    _engine.dispose();
    _socketService.dispose();
    await _micService.dispose();
  }

  String _peerIdFor(InboxCallSession session) {
    final direction = session.direction.name;
    final safeCallId = session.id.replaceAll(RegExp('[^A-Za-z0-9_-]'), '_');
    return 'inbox_${safeCallId}_$direction';
  }
}
