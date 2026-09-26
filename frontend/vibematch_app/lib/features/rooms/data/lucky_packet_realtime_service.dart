import 'dart:async';

import '../../../realtime/app_realtime_hub.dart';
import '../presentation/controllers/live_room_gift_controller.dart';
import 'live_room_system_event_bus.dart';
import 'lucky_packet_api_service.dart';

class LuckyPacketRealtimeService {
  LuckyPacketRealtimeService({
    required String roomId,
    required LiveRoomGiftController giftController,
    LuckyPacketApiService api = const LuckyPacketApiService(),
    AppRealtimeHub? realtimeHub,
  }) : _roomId = roomId.trim(),
       _giftController = giftController,
       _api = api,
       _realtimeHub = realtimeHub ?? AppRealtimeHub.shared;

  static const int _claimWindowSeconds = 20;
  static const int _resultsSeconds = 6;

  final String _roomId;
  final LiveRoomGiftController _giftController;
  final LuckyPacketApiService _api;
  final AppRealtimeHub _realtimeHub;
  final Set<String> _handledEventIds = <String>{};
  Timer? _timer;
  StreamSubscription<dynamic>? _eventSubscription;
  bool _attached = false;
  bool _finalizeInFlight = false;

  void attach() {
    if (_attached || _roomId.isEmpty) return;
    _attached = true;
    _eventSubscription = _realtimeHub.events.listen((envelope) {
      final event = decodeLiveRoomSystemEvent(
        envelope,
        roomId: _roomId,
      );
      if (event != null) _handleSystemEvent(event);
    });
    unawaited(_realtimeHub.start());
    unawaited(refreshActive());
  }

  void dispose() {
    _attached = false;
    unawaited(_eventSubscription?.cancel());
    _eventSubscription = null;
    _timer?.cancel();
    _timer = null;
    _handledEventIds.clear();
  }

  Future<LuckyPacketApiResult> create({
    required int coinAmount,
    required int winnerCount,
    required String message,
  }) async {
    if (_roomId.isEmpty) {
      throw StateError('No active room is available for Lucky Packet');
    }
    final result = await _api.create(
      roomPublicId: _roomId,
      coinAmount: coinAmount,
      winnerCount: winnerCount,
      message: message,
    );
    _applyApiResult(result);
    return result;
  }

  Future<void> refreshActive() async {
    if (_roomId.isEmpty) return;
    try {
      final result = await _api.fetchActive(roomPublicId: _roomId);
      if (result == null) {
        _giftController.applyAuthoritativeLuckyPacket(null);
        return;
      }
      _applyApiResult(result);
    } catch (_) {
      // Room entry remains usable while packet state retries via realtime.
    }
  }

  Future<void> refreshPacket(String packetId) async {
    if (packetId.trim().isEmpty) return;
    try {
      _applyApiResult(await _api.fetchPacket(packetId));
    } catch (_) {
      // Realtime state remains visible while a later event retries refresh.
    }
  }

  Future<void> claim() async {
    final packet = _giftController.activeLuckyPacket;
    if (packet == null || packet.phase != LuckyPacketPhase.claim) return;
    try {
      _applyApiResult(await _api.claim(packet.id));
    } catch (_) {
      unawaited(refreshPacket(packet.id));
    }
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    _giftController.applyAuthoritativeLuckyPacket(null);
  }

  void _handleSystemEvent(LiveRoomSystemEvent event) {
    if (!_handledEventIds.add(event.id)) return;
    if (event.type != 'lucky_packet_created' &&
        event.type != 'lucky_packet_claimed' &&
        event.type != 'lucky_packet_results') {
      return;
    }

    if (event.type == 'lucky_packet_created') {
      _publish(
        LuckyPacketRoomEvent(
          id: event.giftId,
          senderName: event.actorName.trim().isEmpty
              ? 'Vibe User'
              : event.actorName.trim(),
          coinAmount: event.giftTotalCoinValue,
          winnerCount: event.giftQuantity,
          message: event.giftName,
          phase: _phaseFrom(event.giftCategory),
          remainingSeconds: event.autoDismissSeconds ?? 30,
        ),
      );
      return;
    }

    final current = _giftController.activeLuckyPacket;
    if (current == null || current.id != event.giftId) {
      unawaited(refreshPacket(event.giftId));
      return;
    }

    if (event.type == 'lucky_packet_claimed') {
      final distributions = Map<String, int>.from(current.distributions);
      final claimName = event.targetName.trim();
      if (claimName.isNotEmpty && event.luckyRewardCoinAmount > 0) {
        distributions[claimName] = event.luckyRewardCoinAmount;
      }
      final isCurrentClaim = _sameRoomUserId(
        _giftController.currentUser.id,
        event.targetUserId,
      );
      _publish(
        current.copyWith(
          phase: _phaseFrom(event.giftCategory),
          remainingSeconds:
              event.autoDismissSeconds ?? current.remainingSeconds,
          claimedByCurrentUser:
              current.claimedByCurrentUser || isCurrentClaim,
          currentUserReward: isCurrentClaim
              ? event.luckyRewardCoinAmount
              : current.currentUserReward,
          distributions: distributions,
        ),
      );
      return;
    }

    _publish(
      current.copyWith(
        phase: LuckyPacketPhase.results,
        remainingSeconds: event.autoDismissSeconds ?? _resultsSeconds,
      ),
    );
    unawaited(refreshPacket(event.giftId));
  }

  void _applyApiResult(LuckyPacketApiResult result) {
    _publish(
      LuckyPacketRoomEvent(
        id: result.packetId,
        senderName: result.senderName,
        coinAmount: result.coinAmount,
        winnerCount: result.winnerCount,
        message: result.message,
        phase: _phaseFrom(result.phase),
        remainingSeconds: result.remainingSeconds,
        claimedByCurrentUser: result.currentUserReward != null,
        currentUserReward: result.currentUserReward,
        distributions: result.claims,
      ),
    );
  }

  LuckyPacketPhase _phaseFrom(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'claim':
        return LuckyPacketPhase.claim;
      case 'results':
        return LuckyPacketPhase.results;
      default:
        return LuckyPacketPhase.countdown;
    }
  }

  void _publish(LuckyPacketRoomEvent packet) {
    _giftController.applyAuthoritativeLuckyPacket(packet);
    _startClock(packet.id);
  }

  void _startClock(String packetId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final packet = _giftController.activeLuckyPacket;
      if (packet == null || packet.id != packetId) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      if (packet.remainingSeconds > 1) {
        _giftController.applyAuthoritativeLuckyPacket(
          packet.copyWith(remainingSeconds: packet.remainingSeconds - 1),
        );
        return;
      }

      switch (packet.phase) {
        case LuckyPacketPhase.countdown:
          _giftController.applyAuthoritativeLuckyPacket(
            packet.copyWith(
              phase: LuckyPacketPhase.claim,
              remainingSeconds: _claimWindowSeconds,
            ),
          );
          return;
        case LuckyPacketPhase.claim:
          _giftController.applyAuthoritativeLuckyPacket(
            packet.copyWith(
              phase: LuckyPacketPhase.results,
              remainingSeconds: _resultsSeconds,
            ),
          );
          unawaited(_finalize(packet.id));
          return;
        case LuckyPacketPhase.results:
          dismiss();
          return;
      }
    });
  }

  Future<void> _finalize(String packetId) async {
    if (_finalizeInFlight) return;
    _finalizeInFlight = true;
    try {
      _applyApiResult(await _api.finalize(packetId));
    } catch (_) {
      await Future<void>.delayed(const Duration(seconds: 1));
      unawaited(refreshPacket(packetId));
    } finally {
      _finalizeInFlight = false;
    }
  }

  bool _sameRoomUserId(String? left, String? right) {
    String normalize(String? value) {
      final text = value?.trim().toLowerCase() ?? '';
      if (text.startsWith('user_')) return text.substring(5);
      return text;
    }

    final a = normalize(left);
    final b = normalize(right);
    return a.isNotEmpty && a == b;
  }
}
