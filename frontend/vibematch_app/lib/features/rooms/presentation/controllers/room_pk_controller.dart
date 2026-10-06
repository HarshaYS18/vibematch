import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/vm_failure.dart';

import '../../../../foundation/realtime/realtime_event_envelope.dart';
import '../../../../realtime/app_realtime_hub.dart';
import '../../data/room_pk_api_service.dart';

enum RoomPkPresentationPhase {
  idle,
  outgoingChallenge,
  incomingChallenge,
  intro,
  live,
  victory,
  defeat,
  draw,
  settled,
}

class RoomPkController extends ChangeNotifier {
  RoomPkController({
    required this.roomId,
    AppRealtimeHub? realtimeHub,
    RoomPkApiService? api,
  }) : _realtimeHub = realtimeHub ?? AppRealtimeHub.shared,
       _api = api ?? const RoomPkApiService();

  final String roomId;
  final AppRealtimeHub _realtimeHub;
  final RoomPkApiService _api;

  StreamSubscription<RealtimeEventEnvelope>? _subscription;
  StreamSubscription<RealtimeResyncRequest>? _resyncSubscription;
  Timer? _phaseTimer;
  Timer? _finishTimer;
  RoomPkMatchSnapshot? _match;
  RoomPkPresentationPhase _phase = RoomPkPresentationPhase.idle;
  bool _loading = false;
  bool _actionPending = false;
  String? _error;

  RoomPkMatchSnapshot? get match => _match;
  RoomPkPresentationPhase get phase => _phase;
  bool get loading => _loading;
  bool get actionPending => _actionPending;
  String? get error => _error;
  bool get active => _match?.isActive == true;
  bool get pending => _match?.isPending == true;

  RoomPkRoomSummary? get localRoom {
    final value = _match;
    return value == null || !value.involvesRoom(roomId)
        ? null
        : value.roomFor(roomId);
  }

  RoomPkRoomSummary? get opponentRoom {
    final value = _match;
    return value == null || !value.involvesRoom(roomId)
        ? null
        : value.opponentFor(roomId);
  }

  int get localScore => _match?.scoreFor(roomId) ?? 0;
  int get opponentScore => _match?.opponentScoreFor(roomId) ?? 0;

  bool get isIncomingChallenge {
    final value = _match;
    return value?.isPending == true && value!.opponent.roomId == roomId;
  }

  bool get isOutgoingChallenge {
    final value = _match;
    return value?.isPending == true && value!.challenger.roomId == roomId;
  }

  Future<void> initialize() async {
    _subscription ??= _realtimeHub.events.listen(_handleRealtime);
    _resyncSubscription ??=
        _realtimeHub.resyncRequests.listen(_handleRealtimeResync);
    await _realtimeHub.start();
    await refresh(showLoading: false);
  }

  Future<List<RoomPkRoomSummary>> loadCandidates() {
    return _api.listCandidates(roomId);
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final value = await _api.current(roomId);
      _applySnapshot(value, eventType: 'snapshot');
    } catch (error) {
      _error = VmFailurePresentation.messageFor(
        error,
        contentLabel: 'PK battle',
      );
      notifyListeners();
    } finally {
      if (showLoading) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> challenge(
    RoomPkRoomSummary opponent, {
    int durationSeconds = 180,
  }) async {
    if (_actionPending) return;
    _actionPending = true;
    _error = null;
    notifyListeners();
    try {
      final value = await _api.challenge(
        roomId: roomId,
        opponentRoomId: opponent.roomId,
        durationSeconds: durationSeconds,
      );
      _applySnapshot(value, eventType: 'challenge_created');
    } catch (error) {
      _error = VmFailurePresentation.messageFor(
        error,
        contentLabel: 'PK challenge',
      );
    } finally {
      _actionPending = false;
      notifyListeners();
    }
  }

  Future<void> accept() => _decide(true);

  Future<void> decline() => _decide(false);

  Future<void> _decide(bool accept) async {
    final value = _match;
    if (_actionPending || value == null) return;
    _actionPending = true;
    notifyListeners();
    try {
      final next = await _api.decide(
        roomId: roomId,
        matchId: value.matchId,
        accept: accept,
      );
      _applySnapshot(
        next,
        eventType: accept ? 'challenge_accepted' : 'challenge_declined',
      );
    } catch (error) {
      _error = VmFailurePresentation.messageFor(
        error,
        contentLabel: 'PK challenge',
      );
    } finally {
      _actionPending = false;
      notifyListeners();
    }
  }

  Future<void> cancelOrEnd() async {
    final value = _match;
    if (_actionPending || value == null) return;
    _actionPending = true;
    notifyListeners();
    try {
      final next = value.isActive
          ? await _api.finish(roomId: roomId, matchId: value.matchId)
          : await _api.cancel(roomId: roomId, matchId: value.matchId);
      _applySnapshot(next, eventType: value.isActive ? 'finished' : 'cancelled');
    } catch (error) {
      _error = VmFailurePresentation.messageFor(
        error,
        contentLabel: 'PK battle',
      );
    } finally {
      _actionPending = false;
      notifyListeners();
    }
  }

  void _handleRealtimeResync(RealtimeResyncRequest request) {
    final requestedRoom = request.roomId?.trim();
    if (requestedRoom != null &&
        requestedRoom.isNotEmpty &&
        requestedRoom != roomId) {
      return;
    }
    if (request.stream != '*' &&
        request.stream.isNotEmpty &&
        !request.stream.startsWith('room:$roomId:')) {
      return;
    }
    unawaited(refresh(showLoading: false));
  }

  void _handleRealtime(RealtimeEventEnvelope envelope) {
    final decoded = envelope.toLegacyEvent();
    if (decoded['type']?.toString() != 'room_pk/state') return;
    final raw = decoded['payload'];
    if (raw is! Map) return;
    final payload = raw.cast<String, dynamic>();
    final rawPk = payload['pk'];
    if (rawPk is! Map) return;
    final snapshot = RoomPkMatchSnapshot.fromJson(
      rawPk.cast<String, dynamic>(),
    );
    if (!snapshot.involvesRoom(roomId)) return;
    _applySnapshot(
      snapshot,
      eventType: payload['event_type']?.toString() ?? 'state',
    );
  }

  void _applySnapshot(
    RoomPkMatchSnapshot? snapshot, {
    required String eventType,
  }) {
    _phaseTimer?.cancel();
    _finishTimer?.cancel();
    _match = snapshot;
    _error = null;

    if (snapshot == null) {
      _phase = RoomPkPresentationPhase.idle;
      notifyListeners();
      return;
    }

    if (snapshot.isPending) {
      _phase = snapshot.opponent.roomId == roomId
          ? RoomPkPresentationPhase.incomingChallenge
          : RoomPkPresentationPhase.outgoingChallenge;
      notifyListeners();
      return;
    }

    if (snapshot.isActive) {
      final startedRecently = snapshot.startedAt != null &&
          DateTime.now().toUtc().difference(snapshot.startedAt!).abs() <
              const Duration(seconds: 6);
      if (eventType == 'challenge_accepted' || startedRecently) {
        _phase = RoomPkPresentationPhase.intro;
        notifyListeners();
        _phaseTimer = Timer(const Duration(milliseconds: 3200), () {
          if (_match?.isActive != true) return;
          _phase = RoomPkPresentationPhase.live;
          notifyListeners();
        });
      } else {
        _phase = RoomPkPresentationPhase.live;
        notifyListeners();
      }
      _scheduleFinishRefresh(snapshot);
      return;
    }

    if (snapshot.status == 'finished') {
      if (snapshot.winnerRoomId == null) {
        _phase = RoomPkPresentationPhase.draw;
      } else if (snapshot.winnerRoomId == roomId) {
        _phase = RoomPkPresentationPhase.victory;
      } else {
        _phase = RoomPkPresentationPhase.defeat;
      }
      notifyListeners();
      _phaseTimer = Timer(const Duration(milliseconds: 4600), () {
        _phase = RoomPkPresentationPhase.settled;
        notifyListeners();
      });
      return;
    }

    _phase = RoomPkPresentationPhase.settled;
    notifyListeners();
  }

  void _scheduleFinishRefresh(RoomPkMatchSnapshot snapshot) {
    final endsAt = snapshot.endsAt;
    if (endsAt == null) return;
    var delay = endsAt.difference(DateTime.now().toUtc());
    if (delay.isNegative) delay = Duration.zero;
    _finishTimer = Timer(delay + const Duration(milliseconds: 250), () {
      unawaited(refresh(showLoading: false));
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _finishTimer?.cancel();
    unawaited(_subscription?.cancel());
    unawaited(_resyncSubscription?.cancel());
    super.dispose();
  }
}
