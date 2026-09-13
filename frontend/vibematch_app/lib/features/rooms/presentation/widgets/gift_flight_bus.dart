import 'package:flutter/foundation.dart';

import 'gift_flight_overlay.dart';

class GiftFlightBus {
  const GiftFlightBus._();

  static final ValueNotifier<GiftFlightEvent?> latest =
      ValueNotifier<GiftFlightEvent?>(null);

  static String? _lastBackendKey;
  static DateTime? _lastBackendAt;

  static bool _isBackend(GiftFlightEvent event) =>
      event.id.startsWith('flight-gift_');

  static String _key(GiftFlightEvent event) =>
      '${event.senderName.trim().toLowerCase()}|'
      '${event.receiverName.trim().toLowerCase()}|'
      '${event.gift.name.trim().toLowerCase()}|${event.combo}|'
      '${event.multiplier ?? 0}|${event.rewardCoinAmount ?? 0}';

  static void publish(GiftFlightEvent event) {
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
      // The HTTP sender path still creates a local animation. Ignore that
      // echo when the authoritative room event has already driven the flight.
      return;
    }

    latest.value = event;
  }

  static void clear() {
    latest.value = null;
  }
}
