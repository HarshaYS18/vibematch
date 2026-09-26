import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/room_session/domain/room_session_state.dart';

Map<String, dynamic> _snapshot({
  required List<Map<String, dynamic>> participants,
  required List<Map<String, dynamic>> roster,
  List<Map<String, dynamic>> pending = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'room_id': 'VM100',
    'state_version': 10,
    'participants': participants,
    'membership_roster': roster,
    'pending_room_member_requests': pending,
    'seats': const <Map<String, dynamic>>[],
  };
}

void main() {
  test('durable membership is separate from online presence', () {
    final state = RoomSessionState.fromSnapshot(
      _snapshot(
        participants: const <Map<String, dynamic>>[
          <String, dynamic>{
            'backend_user_id': 1,
            'public_user_id': 101,
            'is_active': true,
            'is_room_member': false,
          },
        ],
        roster: const <Map<String, dynamic>>[
          <String, dynamic>{
            'backend_user_id': 2,
            'public_user_id': 202,
            'is_room_member': true,
          },
        ],
      ),
      connection: RoomSessionConnection.connected,
    );

    expect(state.presence.containsKey(1), isTrue);
    expect(state.members.contains(1), isFalse);
    expect(state.presence.containsKey(2), isFalse);
    expect(state.members.contains(2), isTrue);
  });

  test('backend roster removal clears canonical membership on next snapshot', () {
    final first = RoomSessionState.fromSnapshot(
      _snapshot(
        participants: const <Map<String, dynamic>>[],
        roster: const <Map<String, dynamic>>[
          <String, dynamic>{
            'backend_user_id': 2,
            'public_user_id': 202,
            'is_room_member': true,
          },
        ],
      ),
      connection: RoomSessionConnection.connected,
    );
    final second = RoomSessionState.fromSnapshot(
      _snapshot(
        participants: const <Map<String, dynamic>>[],
        roster: const <Map<String, dynamic>>[],
      ),
      connection: RoomSessionConnection.connected,
    );

    expect(first.members.contains(2), isTrue);
    expect(second.members.contains(2), isFalse);
  });

  test('pending membership requests are canonical room activity state', () {
    final state = RoomSessionState.fromSnapshot(
      _snapshot(
        participants: const <Map<String, dynamic>>[],
        roster: const <Map<String, dynamic>>[],
        pending: const <Map<String, dynamic>>[
          <String, dynamic>{
            'backend_user_id': 7,
            'public_user_id': 707,
            'display_name': 'Pending User',
          },
        ],
      ),
      connection: RoomSessionConnection.connected,
    );

    final pending =
        state.activities['pending_room_member_requests'] as List<dynamic>;
    expect(pending, hasLength(1));
    expect(
      (pending.single as Map<String, dynamic>)['public_user_id'],
      707,
    );
  });

  test('membership aliases remain available on canonical roster entry', () {
    final state = RoomSessionState.fromSnapshot(
      _snapshot(
        participants: const <Map<String, dynamic>>[],
        roster: const <Map<String, dynamic>>[
          <String, dynamic>{
            'backend_user_id': 7,
            'public_user_id': 707,
            'is_room_member': true,
            'is_room_admin': true,
          },
        ],
      ),
      connection: RoomSessionConnection.connected,
    );

    final entry = state.membershipRoster[7];
    expect(entry, isNotNull);
    expect(entry!.backendUserId, 7);
    expect(entry.publicUserId, 707);
    expect(entry.isMember, isTrue);
    expect(entry.isAdmin, isTrue);
  });
}
