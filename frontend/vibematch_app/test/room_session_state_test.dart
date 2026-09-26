import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/room_session/domain/room_session_state.dart';

Map<String, dynamic> _snapshot({
  required int version,
  bool includeSecondUser = true,
}) {
  return <String, dynamic>{
    'room_id': 'VM123',
    'name': 'Canonical Room',
    'state_version': version,
    'online_count': includeSecondUser ? 3 : 2,
    'public_online_count': includeSecondUser ? 3 : 2,
    'participants': <Map<String, dynamic>>[
      <String, dynamic>{
        'backend_user_id': 1,
        'public_user_id': 101,
        'display_name': 'Visitor',
        'is_active': true,
        'is_room_member': false,
        'is_room_admin': false,
        'seat_index': null,
      },
      if (includeSecondUser)
        <String, dynamic>{
          'backend_user_id': 2,
          'public_user_id': 202,
          'display_name': 'Member',
          'is_active': true,
          'is_room_member': true,
          'is_room_admin': false,
          'seat_index': null,
        },
      <String, dynamic>{
        'backend_user_id': 3,
        'public_user_id': 303,
        'display_name': 'Admin',
        'is_active': true,
        'is_room_member': true,
        'is_room_admin': true,
        'seat_index': 2,
        'mic_enabled': true,
      },
    ],
    'membership_roster': <Map<String, dynamic>>[
      if (includeSecondUser)
        <String, dynamic>{
          'backend_user_id': 2,
          'public_user_id': 202,
          'is_room_member': true,
          'is_room_admin': false,
        },
      <String, dynamic>{
        'backend_user_id': 3,
        'public_user_id': 303,
        'is_room_member': true,
        'is_room_admin': true,
      },
      <String, dynamic>{
        'backend_user_id': 4,
        'public_user_id': 404,
        'is_room_member': true,
        'is_room_admin': false,
      },
    ],
    'seats': <Map<String, dynamic>>[
      <String, dynamic>{
        'seat_index': 0,
        'occupant_user_id': null,
        'is_locked': false,
        'mic_enabled': false,
      },
      <String, dynamic>{
        'seat_index': 2,
        'occupant_backend_user_id': 3,
        'occupant_public_user_id': 303,
        'is_locked': false,
        'mic_enabled': true,
      },
    ],
    'recent_messages': <Map<String, dynamic>>[],
  };
}

void main() {
  test('presence membership audience and seat occupancy stay independent', () {
    final state = RoomSessionState.fromSnapshot(
      _snapshot(version: 10),
      connection: RoomSessionConnection.connected,
    );

    final visitor = state.presence[1]!;
    expect(visitor.isPresent, isTrue);
    expect(visitor.isMember, isFalse);
    expect(visitor.isSeated, isFalse);
    expect(state.audience.containsKey(1), isTrue);

    final member = state.presence[2]!;
    expect(member.isMember, isTrue);
    expect(member.isSeated, isFalse);
    expect(state.audience.containsKey(2), isTrue);

    final admin = state.presence[3]!;
    expect(admin.isAdmin, isTrue);
    expect(admin.isSeated, isTrue);
    expect(admin.micEnabled, isTrue);
    expect(state.audience.containsKey(3), isFalse);

    expect(state.members, containsAll(<int>{2, 3, 4}));
    expect(state.membershipRoster[4], isNotNull);
    expect(state.presence.containsKey(4), isFalse);
    expect(state.seats[2]!.occupantBackendUserId, 3);
  });

  test('full snapshots converge after leave and reconnect transitions', () {
    final joined = RoomSessionState.fromSnapshot(
      _snapshot(version: 20),
      connection: RoomSessionConnection.connected,
    );
    final afterLeave = RoomSessionState.fromSnapshot(
      _snapshot(version: 21, includeSecondUser: false),
      connection: RoomSessionConnection.connected,
    );
    final afterReconnect = RoomSessionState.fromSnapshot(
      _snapshot(version: 22),
      connection: RoomSessionConnection.connected,
    );

    expect(joined.presence.containsKey(2), isTrue);
    expect(afterLeave.presence.containsKey(2), isFalse);
    expect(afterReconnect.presence.containsKey(2), isTrue);
    expect(afterReconnect.stateVersion, 22);
  });
}
