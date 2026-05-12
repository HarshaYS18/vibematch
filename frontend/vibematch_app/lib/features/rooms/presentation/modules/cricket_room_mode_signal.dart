import 'package:flutter/foundation.dart';

class CricketQuickMatchPlayerSetup {
  const CricketQuickMatchPlayerSetup({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class CricketQuickMatchTeamSetup {
  const CricketQuickMatchTeamSetup({
    required this.id,
    required this.name,
    required this.players,
  });

  final String id;
  final String name;
  final List<CricketQuickMatchPlayerSetup> players;
}

class CricketQuickMatchSetup {
  const CricketQuickMatchSetup({
    required this.roomId,
    required this.roomName,
    required this.teamA,
    required this.teamB,
    required this.overs,
    required this.wickets,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.strikerId,
    required this.nonStrikerId,
    required this.bowlerId,
  });

  final String roomId;
  final String roomName;
  final CricketQuickMatchTeamSetup teamA;
  final CricketQuickMatchTeamSetup teamB;
  final int overs;
  final int wickets;
  final String battingTeamId;
  final String bowlingTeamId;
  final String strikerId;
  final String nonStrikerId;
  final String bowlerId;
}

class CricketRoomModeSignal {
  CricketRoomModeSignal._();

  static final ValueNotifier<Set<String>> activeRoomIds =
      ValueNotifier<Set<String>>(<String>{});

  static final ValueNotifier<Map<String, CricketQuickMatchSetup>> matchSetups =
      ValueNotifier<Map<String, CricketQuickMatchSetup>>(
    <String, CricketQuickMatchSetup>{},
  );

  static bool isActive(String roomId) {
    return activeRoomIds.value.contains(roomId.trim());
  }

  static CricketQuickMatchSetup? setupFor(String roomId) {
    return matchSetups.value[roomId.trim()];
  }

  static void activate(String roomId) {
    final safeRoomId = roomId.trim();
    if (safeRoomId.isEmpty) return;

    activeRoomIds.value = <String>{...activeRoomIds.value, safeRoomId};
  }

  static void activateWithSetup({
    required String roomId,
    required CricketQuickMatchSetup setup,
  }) {
    final safeRoomId = roomId.trim();
    if (safeRoomId.isEmpty) return;

    matchSetups.value = <String, CricketQuickMatchSetup>{
      ...matchSetups.value,
      safeRoomId: setup,
    };
    activeRoomIds.value = <String>{...activeRoomIds.value, safeRoomId};
  }

  static void deactivate(String roomId) {
    final safeRoomId = roomId.trim();
    if (safeRoomId.isEmpty) return;

    final nextActive = <String>{...activeRoomIds.value}..remove(safeRoomId);
    final nextSetups = <String, CricketQuickMatchSetup>{...matchSetups.value}
      ..remove(safeRoomId);

    activeRoomIds.value = nextActive;
    matchSetups.value = nextSetups;
  }
}