import 'dart:async';

import '../../../realtime/app_realtime_hub.dart';
import '../presentation/controllers/live_room_gift_controller.dart';
import 'active_room_context.dart';
import 'live_room_media_signaling_service.dart';
import 'live_room_system_event_bus.dart';
import 'lucky_packet_api_service.dart';

class LuckyPacketRealtimeService {
  LuckyPacketRealtimeService._();

  static final LuckyPacketRealtimeService instance = LuckyPacketRealtimeService._();

  static const int _claimWindowSeconds = 20;
  static const int _resultsSeconds = 6;

  final LuckyPacketApiService _api = const LuckyPacketApiService();
  final Set<String> _handledEventIds = <String>{};
  Timer? _timer;
  StreamSubscription<dynamic>? _eventSubscription;
  bool _attached = false;
  bool _finalizeInFlight = false;

  void attach() {
    if (!_attached) {
      _attached = true;
      _eventSubscription = AppRealtimeHub.shared.events.listen((envelope) {
        final event = decodeLiveRoomSystemEvent(
          envelope,
          roomId: ActiveRoomContext.roomPublicId,
        );
        if (event != null) _handleSystemEvent(event);
      });
      unawaited(AppRealtimeHub.shared.start());
    }
    unawaited(refreshActive());
  }

  void detach() {
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
    final roomId = ActiveRoomContext.roomPublicId?.trim();
    if (roomId == null || roomId.isEmpty) {
      throw Exception('No active room is available for Lucky Packet');
    }
    final result = await _api.create(
      roomPublicId: roomId,
      coinAmount: coinAmount,
      winnerCount: winnerCount,
      message: message,
    );
    _applyApiResult(result);
    return result;
  }

  Future<void> refreshActive() async {
    final roomId = ActiveRoomContext.roomPublicId?.trim();
    if (roomId == null || roomId.isEmpty) return;
    try {
      final result = await _api.fetchActive(roomPublicId: roomId);
      if (result == null) return;
      _applyApiResult(result);
    } catch (_) {
      // Room entry must remain usable if the packet refresh is temporarily down.
    }
  }

  Future<void> refreshPacket(String packetId) async {
    if (packetId.trim().isEmpty) return;
    try {
      _applyApiResult(await _api.fetchPacket(packetId));
    } catch (_) {
      // Realtime state remains visible while a refresh is retried by later events.
    }
  }

  Future<void> claim() async {
    final packet = LuckyPacketRoomBus.packet.value;
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
    LuckyPacketRoomBus.publish(null);
  }

  void _handleSystemEvent(LiveRoomSystemEvent event) {
    if (!_handledEventIds.add(event.id)) return;
    if (event.type != 'lucky_packet_created' &&
        event.type != 'lucky_packet_claimed' &&
        event.type != 'lucky_packet_results') {
      return;
    }

    if (event.type == 'lucky_packet_created') {
      final packet = LuckyPacketRoomEvent(
        id: event.giftId,
        senderName: event.actorName.trim().isEmpty
            ? 'Vibe User'
            : event.actorName.trim(),
        coinAmount: event.giftTotalCoinValue,
        winnerCount: event.giftQuantity,
        message: event.giftName,
        phase: _phaseFrom(event.giftCategory),
        remainingSeconds: event.autoDismissSeconds ?? 30,
      );
      _publish(packet);
      return;
    }

    final current = LuckyPacketRoomBus.packet.value;
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
      final currentRoomUserId =
          LiveRoomMediaSignalingService.instance.activeLoggedInSeatUser?.id;
      final isCurrentClaim = _sameRoomUserId(
        currentRoomUserId,
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
    LuckyPacketRoomBus.publish(packet);
    _startClock(packet.id);
  }

  void _startClock(String packetId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final packet = LuckyPacketRoomBus.packet.value;
      if (packet == null || packet.id != packetId) {
        _timer?.cancel();
        _timer = null;
        return;
      }
      if (packet.remainingSeconds > 1) {
        LuckyPacketRoomBus.publish(
          packet.copyWith(remainingSeconds: packet.remainingSeconds - 1),
        );
        return;
      }

      switch (packet.phase) {
        case LuckyPacketPhase.countdown:
          LuckyPacketRoomBus.publish(
            packet.copyWith(
              phase: LuckyPacketPhase.claim,
              remainingSeconds: _claimWindowSeconds,
            ),
          );
          return;
        case LuckyPacketPhase.claim:
          LuckyPacketRoomBus.publish(
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
