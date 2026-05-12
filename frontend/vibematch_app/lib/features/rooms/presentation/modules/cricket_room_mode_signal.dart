import 'package:flutter/foundation.dart';

class CricketRoomModeSignal {
  CricketRoomModeSignal._();

  static final ValueNotifier<Set<String>> activeRoomIds =
      ValueNotifier<Set<String>>(<String>{});

  static bool isActive(String roomId) {
    return activeRoomIds.value.contains(roomId);
  }

  static void activate(String roomId) {
    final safeRoomId = roomId.trim();
    if (safeRoomId.isEmpty) return;

    final next = <String>{...activeRoomIds.value, safeRoomId};
    activeRoomIds.value = next;
  }

  static void deactivate(String roomId) {
    final safeRoomId = roomId.trim();
    if (safeRoomId.isEmpty) return;

    final next = <String>{...activeRoomIds.value}..remove(safeRoomId);
    activeRoomIds.value = next;
  }
}