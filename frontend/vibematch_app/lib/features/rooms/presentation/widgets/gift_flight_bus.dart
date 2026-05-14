import 'package:flutter/foundation.dart';

import 'gift_flight_overlay.dart';

class GiftFlightBus {
  const GiftFlightBus._();

  static final ValueNotifier<GiftFlightEvent?> latest = ValueNotifier<GiftFlightEvent?>(null);

  static void publish(GiftFlightEvent event) {
    latest.value = event;
  }

  static void clear() {
    latest.value = null;
  }
}
