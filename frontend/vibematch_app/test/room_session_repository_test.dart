import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/networking/app_network_client.dart';
import 'package:vibematch_app/room_session/data/room_session_repository.dart';
import 'package:vibematch_app/room_session/domain/room_session_state.dart';

class _FakeNetworkClient implements AppNetworkClient {
  _FakeNetworkClient(this.snapshot);

  Map<String, dynamic> snapshot;
  List<String> omittedSections = const <String>[];
  final List<String> calls = <String>[];

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  }) async {
    calls.add('GET $path');
    return <String, dynamic>{'room_id': 'VM123', 'room': snapshot};
  }

  @override
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  }) async {
    calls.add('GET_LIST $path');
    return const <dynamic>[];
  }

  @override
  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async {
    calls.add('POST $path');
    return <String, dynamic>{
      'room_id': 'VM123',
      'room': snapshot,
      if (omittedSections.isNotEmpty) 'snapshot_mode': 'partial',
      if (omittedSections.isNotEmpty) 'omitted_sections': omittedSections,
    };
  }

  @override
  Future<Map<String, dynamic>> patchMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async {
    calls.add('PATCH $path');
    return <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> deleteMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async {
    calls.add('DELETE $path');
    return <String, dynamic>{};
  }

  @override
  void close() {}
}

Map<String, dynamic> _room(int version, List<int> users) {
  return <String, dynamic>{
    'room_id': 'VM123',
    'state_version': version,
    'online_count': users.length,
    'participants': users
        .map(
          (id) => <String, dynamic>{
            'backend_user_id': id,
            'public_user_id': id * 100,
            'display_name': 'User $id',
            'is_active': true,
            'is_room_member': id != 1,
            'is_room_admin': id == 3,
            'seat_index': id == 3 ? 2 : null,
          },
        )
        .toList(),
    'membership_roster': users
        .where((id) => id != 1)
        .map(
          (id) => <String, dynamic>{
            'backend_user_id': id,
            'public_user_id': id * 100,
            'is_room_member': true,
            'is_room_admin': id == 3,
          },
        )
        .toList(),
    'seats': <Map<String, dynamic>>[
      <String, dynamic>{
        'seat_index': 2,
        'occupant_backend_user_id': users.contains(3) ? 3 : null,
        'occupant_public_user_id': users.contains(3) ? 300 : null,
      },
    ],
  };
}

void main() {
  test('join is one canonical request returning full room state', () async {
    final network = _FakeNetworkClient(_room(1, <int>[1, 2]));
    final repository = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: network,
      accessTokenProvider: () => 'token',
    );

    final state = await repository.join(lockPassword: 'secret');

    expect(state.connection, RoomSessionConnection.connected);
    expect(state.stateVersion, 1);
    expect(state.presence.keys, containsAll(<int>{1, 2}));
    expect(
      network.calls,
      <String>['POST /rooms/VM123/realtime/join'],
    );
  });

  test('heartbeat is liveness-only and does not replace canonical state', () async {
    final network = _FakeNetworkClient(_room(10, <int>[1, 2]));
    final repository = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: network,
      accessTokenProvider: () => 'token',
    );

    await repository.join();
    network.snapshot = _room(11, <int>[1, 2, 3]);

    final heartbeat = await repository.heartbeat();

    expect(heartbeat.stateVersion, 10);
    expect(heartbeat.presence.containsKey(3), isFalse);
    expect(heartbeat.connection, RoomSessionConnection.connected);

    network.snapshot = _room(12, <int>[2, 3]);
    final left = await repository.leave();
    expect(left.connection, RoomSessionConnection.left);
    expect(left.stateVersion, 12);
    expect(
      network.calls,
      containsAllInOrder(<String>[
        'POST /rooms/VM123/realtime/join',
        'POST /rooms/VM123/realtime/heartbeat',
        'POST /rooms/VM123/realtime/leave',
      ]),
    );
  });

  test('room-state-v2 delta merges only supplied canonical sections', () async {
    final initial = _room(30, <int>[1, 2])
      ..['event_sequence'] = 40
      ..['recent_messages'] = <Map<String, dynamic>>[
        <String, dynamic>{'id': 'm1', 'text': 'keep me'},
      ];
    final network = _FakeNetworkClient(initial);
    final repository = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: network,
      accessTokenProvider: () => 'token',
    );

    await repository.join();
    final nextParticipants = _room(31, <int>[1, 2, 3])['participants'];
    final next = repository.reconcileDelta(<String, dynamic>{
      'room_id': 'VM123',
      'room_version': 31,
      'event_sequence': 41,
      'participants': nextParticipants,
      'online_count': 3,
    });

    expect(next.stateVersion, 31);
    expect(next.eventSequence, 41);
    expect(next.presence.containsKey(3), isTrue);
    expect(next.chat.single['id'], 'm1');
  });

  test('gateway envelope delegates room-state-v2 delta to repository', () async {
    final network = _FakeNetworkClient(_room(35, <int>[1]));
    final repository = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: network,
      accessTokenProvider: () => 'token',
    );
    await repository.join();

    final state = repository.reconcileRealtimeEvent(<String, dynamic>{
      'event_id': 'evt-1',
      'stream': 'room:VM123:epoch-a',
      'sequence': 7,
      'payload': <String, dynamic>{
        'type': 'seat/taken',
        'payload': <String, dynamic>{
          'protocol': 'room-state-v2',
          'delta': <String, dynamic>{
            'room_id': 'VM123',
            'room_version': 36,
            'event_sequence': 52,
            'online_count': 1,
          },
        },
      },
    });

    expect(state.stateVersion, 36);
    expect(state.eventSequence, 52);
  });

  test('two client projections converge across join leave reconnect', () async {
    final server = _FakeNetworkClient(_room(20, <int>[1]));
    final clientA = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: server,
      accessTokenProvider: () => 'token-a',
    );
    final clientB = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: server,
      accessTokenProvider: () => 'token-b',
    );

    await clientA.join();

    server.snapshot = _room(21, <int>[1, 2]);
    final bJoined = await clientB.join();
    clientA.reconcileSnapshot(server.snapshot);
    expect(clientA.state.presence.keys, bJoined.presence.keys);

    server.snapshot = _room(22, <int>[1]);
    clientA.reconcileSnapshot(server.snapshot);
    clientB.reconcileSnapshot(server.snapshot);
    expect(clientA.state.presence.containsKey(2), isFalse);
    expect(clientB.state.presence.containsKey(2), isFalse);

    server.snapshot = _room(23, <int>[1, 2]);
    final bReconnected = await clientB.refreshAfterReconnect();
    clientA.reconcileSnapshot(server.snapshot);

    expect(clientA.state.stateVersion, 23);
    expect(bReconnected.stateVersion, 23);
    expect(clientA.state.presence.keys, bReconnected.presence.keys);
  });

  test('two clients converge after a seat transition', () async {
    final server = _FakeNetworkClient(_room(40, <int>[1, 2]));
    final clientA = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: server,
      accessTokenProvider: () => 'token-a',
    );
    final clientB = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: server,
      accessTokenProvider: () => 'token-b',
    );

    await clientA.join();
    await clientB.join();

    server.snapshot = _room(41, <int>[1, 2])
      ..['participants'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'backend_user_id': 1,
          'public_user_id': 100,
          'display_name': 'User 1',
          'is_active': true,
          'is_room_member': false,
          'is_room_admin': false,
          'seat_index': null,
        },
        <String, dynamic>{
          'backend_user_id': 2,
          'public_user_id': 200,
          'display_name': 'User 2',
          'is_active': true,
          'is_room_member': true,
          'is_room_admin': false,
          'seat_index': 1,
          'mic_enabled': true,
        },
      ]
      ..['seats'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'seat_index': 1,
          'occupant_backend_user_id': 2,
          'occupant_public_user_id': 200,
          'mic_enabled': true,
        },
      ];

    final afterTake = await clientB.takeSeat(1);
    clientA.reconcileSnapshot(server.snapshot);

    expect(afterTake.presence[2]!.seatIndex, 1);
    expect(clientA.state.presence[2]!.seatIndex, 1);
    expect(clientA.state.seats[1]!.occupantBackendUserId, 2);
    expect(clientB.state.seats[1]!.occupantBackendUserId, 2);
  });

  test('activity command stays on canonical room repository', () async {
    final server = _FakeNetworkClient(_room(45, <int>[1, 2]));
    final repository = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: server,
      accessTokenProvider: () => 'token',
    );
    await repository.join();
    await repository.activityCommand(
      action: 'START',
      kind: 'karaoke',
      activityId: 'karaoke-night',
      title: 'Karaoke Night',
    );
    expect(
      server.calls,
      contains('POST /rooms/VM123/realtime/activity/command'),
    );
  });

  test('older realtime snapshot cannot roll canonical state backward', () {
    final network = _FakeNetworkClient(_room(50, <int>[1, 2, 3]));
    final repository = RoomSessionRepository(
      roomId: 'VM123',
      networkClient: network,
      accessTokenProvider: () => 'token',
    );

    repository.reconcileSnapshot(
      _room(50, <int>[1, 2, 3]),
      force: true,
    );
    repository.reconcileSnapshot(_room(49, <int>[1]));

    expect(repository.state.stateVersion, 50);
    expect(repository.state.presence.keys, containsAll(<int>{1, 2, 3}));
  });
}
