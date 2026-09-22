import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chunk 5 canonical room state keeps domain concepts separate', () {
    final state = File(
      'lib/room_session/domain/room_session_state.dart',
    ).readAsStringSync();
    final repository = File(
      'lib/room_session/data/room_session_repository.dart',
    ).readAsStringSync();
    final shell = File(
      'lib/features/rooms/presentation/live_room_presence_shell_page.dart',
    ).readAsStringSync();

    expect(state, contains('final Map<int, RoomSessionParticipant> presence'));
    expect(state, contains('final Map<int, RoomSessionParticipant> audience'));
    expect(state, contains('final Map<int, RoomMembershipEntry> membershipRoster'));
    expect(state, contains('final Map<int, RoomSessionSeat> seats'));
    expect(repository, contains('/realtime/join'));
    expect(repository, contains('/realtime/heartbeat'));
    expect(repository, contains('/realtime/snapshot'));
    expect(shell, contains('roomSessionRepositoryProvider'));
    expect(repository, isNot(contains('ValueNotifier')));
    expect(repository, isNot(contains('package:http/http.dart')));
  });
}
