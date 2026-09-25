import 'package:flutter/foundation.dart';

import 'gift_flight_overlay.dart';

/// Room-scoped presentation queue for one active flying-gift animation.
///
/// Ownership: [LiveRoomGiftController]. The queue intentionally contains only
/// ephemeral animation state; gift economy and delivery authority remain in the
/// backend/canonical room event stream. Backend-vs-local dedupe is retained per
/// mounted room and is discarded when the room controller is disposed.
class GiftFlightBus {
  GiftFlightBus();

  final ValueNotifier<GiftFlightEvent?> latest =
      ValueNotifier<GiftFlightEvent?>(null);

  String? _lastBackendKey;
  DateTime? _lastBackendAt;

  bool _isBackend(GiftFlightEvent event) =>
      event.id.startsWith('flight-gift_');

  String _key(GiftFlightEvent event) =>
      '${event.senderName.trim().toLowerCase()}|'
      '${event.receiverName.trim().toLowerCase()}|'
      '${event.gift.name.trim().toLowerCase()}|${event.combo}|'
      '${event.multiplier ?? 0}|${event.rewardCoinAmount ?? 0}';

  void publish(GiftFlightEvent event) {
    final now = DateTime.now();
    final incomingIsBackend = _isBackend(event);
    final key = _key(event);

    if (incomingIsBackend) {
      _lastBackendKey = key;
      _lastBackendAt = now;
      latest.value = event;
      return;
    }

    final backendAt = _lastBackendAt;
    if (_lastBackendKey == key &&
        backendAt != null &&
        now.difference(backendAt) < const Duration(seconds: 2)) {
      return;
    }

    latest.value = event;
  }

  void clear() {
    latest.value = null;
  }

  void dispose() {
    latest.dispose();
    _lastBackendKey = null;
    _lastBackendAt = null;
  }
}
