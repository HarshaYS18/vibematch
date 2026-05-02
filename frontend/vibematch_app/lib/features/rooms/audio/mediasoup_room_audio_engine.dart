import '../../audio_mediasoup/data/mediasoup_audio_engine.dart';
import '../../audio_mediasoup/data/mediasoup_local_mic_service.dart';
import '../../audio_mediasoup/data/mediasoup_socket_service.dart';
import '../../audio_mediasoup/models/mediasoup_producer_state.dart';
import '../../audio_mediasoup/models/mediasoup_room_state.dart';
import '../../audio_mediasoup/models/mediasoup_seat_state.dart';
import '../../../core/constants/app_constants.dart';
import 'room_audio_engine.dart';
import 'room_audio_state.dart';

class MediasoupRoomAudioEngine extends RoomAudioEngine {
  MediasoupRoomAudioEngine({
    String? serverUrl,
  }) : _serverUrl = serverUrl ?? AppConstants.mediasoupAudioServerUrl {
    _audioEngine = MediasoupAudioEngine(
      socketService: _socketService,
      micService: _micService,
    );
    _socketService.seatEvents.listen(_handleSeatEvent);
    _socketService.newProducers.listen(_handleNewProducer);
    _socketService.producerClosedEvents.listen(_handleProducerClosed);
    _socketService.logs.listen((message) => _setStatus(message));
    _audioEngine.logs.listen((message) => _setStatus(message));
  }

  final String _serverUrl;
  final MediasoupSocketService _socketService = MediasoupSocketService();
  final MediasoupLocalMicService _micService = MediasoupLocalMicService();
  late final MediasoupAudioEngine _audioEngine;

  String? _roomId;
  String? _peerId;
  MediasoupRoomState? _roomState;
  RoomAudioState _state = const RoomAudioState();

  @override
  RoomAudioState get state => _state;

  @override
  Future<void> joinAsAudience({
    required String roomId,
    required String peerId,
    required String audioToken,
  }) async {
    await leaveRoomAudio();

    _roomId = roomId;
    _peerId = peerId;

    final joinedState = await _socketService.connectAndJoin(
      serverUrl: _serverUrl,
      roomId: roomId,
      peerId: peerId,
      audioToken: audioToken,
    );

    await _audioEngine.loadRoom(joinedState);
    await _audioEngine.consumeExistingProducers(joinedState.producers);

    _roomState = joinedState;
    _state = _state.copyWith(
      connected: true,
      engineLoaded: true,
      publishing: false,
      selfMuted: false,
      clearMySeatNo: true,
      remoteConsumerCount: _audioEngine.remoteConsumerCount,
      status: 'Connected to room audio',
    );
    notifyListeners();
  }

  @override
  Future<void> takeSpeakerSeat(int seatNo) async {
    _requireJoined();
    final response = await _socketService.takeSeat(seatNo);
    _applySeats(MediasoupRoomState.seatsFromEvent(response));

    _state = _state.copyWith(
      mySeatNo: seatNo,
      status: 'Audio seat $seatNo joined',
    );
    notifyListeners();
  }

  @override
  Future<void> leaveSpeakerSeat() async {
    if (!_state.connected) return;

    await stopPublishing();
    final response = await _socketService.leaveSeat();
    _applySeats(MediasoupRoomState.seatsFromEvent(response));

    _state = _state.copyWith(
      clearMySeatNo: true,
      publishing: false,
      selfMuted: false,
      status: 'Left audio seat',
    );
    notifyListeners();
  }

  @override
  Future<void> publishMic() async {
    _requireJoined();
    if (_state.mySeatNo == null) {
      throw StateError('Take an audio seat before publishing mic');
    }

    await _audioEngine.publishMic();
    _state = _state.copyWith(
      publishing: true,
      remoteConsumerCount: _audioEngine.remoteConsumerCount,
      status: 'Mic publishing',
    );
    notifyListeners();
  }

  @override
  Future<void> stopPublishing() async {
    await _audioEngine.stopPublishing();
    await _micService.stopMic();
    _state = _state.copyWith(
      publishing: false,
      selfMuted: false,
      status: 'Mic stopped',
    );
    notifyListeners();
  }

  @override
  Future<void> setSelfMuted(bool muted) async {
    _requireJoined();
    if (_state.mySeatNo == null) {
      throw StateError('Take an audio seat before muting');
    }

    final response = await _socketService.setSelfMuted(muted);
    _applySeats(MediasoupRoomState.seatsFromEvent(response));
    await _audioEngine.setMuted(muted);

    _state = _state.copyWith(
      selfMuted: muted,
      status: muted ? 'Mic muted' : 'Mic unmuted',
    );
    notifyListeners();
  }

  @override
  Future<void> leaveRoomAudio() async {
    await _audioEngine.close();
    await _micService.stopMic();
    await _socketService.disconnect();

    _roomId = null;
    _peerId = null;
    _roomState = null;
    _state = const RoomAudioState(status: 'Audio disconnected');
    notifyListeners();
  }

  @override
  void dispose() {
    _audioEngine.dispose();
    _socketService.dispose();
    _micService.dispose();
    super.dispose();
  }

  Future<void> _handleNewProducer(MediasoupProducerState producer) async {
    try {
      await _audioEngine.consumeProducer(producer);
      _state = _state.copyWith(
        remoteConsumerCount: _audioEngine.remoteConsumerCount,
        status: 'Consuming ${producer.peerId}',
      );
      notifyListeners();
    } catch (error) {
      _setStatus('Consume failed: $error');
    }
  }

  Future<void> _handleProducerClosed(String producerId) async {
    await _audioEngine.closeConsumer(producerId);
    _state = _state.copyWith(
      remoteConsumerCount: _audioEngine.remoteConsumerCount,
      status: 'Remote producer closed',
    );
    notifyListeners();
  }

  void _handleSeatEvent(List<dynamic> rawSeats) {
    final seats = rawSeats
        .whereType<Map>()
        .map((item) => MediasoupSeatState.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
    _applySeats(seats);
  }

  void _applySeats(List<MediasoupSeatState> seats) {
    final existing = _roomState;
    if (existing != null) {
      _roomState = existing.copyWith(seats: seats);
    }

    final mySeatNo = _findMySeatNo(seats);
    _state = _state.copyWith(
      mySeatNo: mySeatNo,
      clearMySeatNo: mySeatNo == null,
    );
    notifyListeners();
  }

  int? _findMySeatNo(List<MediasoupSeatState> seats) {
    final peerId = _peerId;
    if (peerId == null) return null;

    for (final seat in seats) {
      if (seat.peerId == peerId) return seat.seatNo;
    }
    return null;
  }

  void _setStatus(String status) {
    _state = _state.copyWith(status: status);
    notifyListeners();
  }

  void _requireJoined() {
    if (_roomId == null || _peerId == null || !_state.connected) {
      throw StateError('Room audio is not connected');
    }
  }
}
