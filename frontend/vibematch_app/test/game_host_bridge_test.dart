import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/networking/app_network_client.dart';
import 'package:vibematch_app/game_platform/application/game_host_bridge.dart';

void main() {
  test('host context never exposes the app access token or game session id', () async {
    final api = _FakeNetworkClient();
    final bridge = GameHostBridge(
      api: api,
      accessToken: 'secret-token',
      gameId: 'jungle_hunt',
      bridgeVersion: 1,
      roomId: '42',
      onClose: () {},
    );
    await bridge.initialize();

    final response = await bridge.handle(<String, dynamic>{
      'method': 'host.context',
    });

    expect(response['ok'], isTrue);
    expect(response.toString(), isNot(contains('secret-token')));
    expect(response.toString(), isNot(contains('session-123')));
    expect(
      response['data'],
      <String, dynamic>{
        'gameId': 'jungle_hunt',
        'roomId': '42',
        'bridgeVersion': 1,
      },
    );
  });

  test('opens a durable session and binds created rounds to it', () async {
    final api = _FakeNetworkClient();
    final bridge = GameHostBridge(
      api: api,
      accessToken: 'secret-token',
      gameId: 'jungle_hunt',
      bridgeVersion: 1,
      roomId: '42',
      onClose: () {},
    );

    final created = await bridge.handle(<String, dynamic>{
      'method': 'game.round.create',
    });
    expect(created['ok'], isTrue);
    expect(api.postPaths.first, '/games/jungle_hunt/sessions');
    expect(api.roundCreateBody?['session_id'], 'session-123');
    expect(api.roundCreateBody?['room_id'], 42);

    final accepted = await bridge.handle(<String, dynamic>{
      'method': 'game.bet.place',
      'params': <String, dynamic>{
        'roundId': 77,
        'targetId': 4,
        'amount': 10000,
      },
    });
    expect(accepted['ok'], isTrue);
    expect(api.lastAuthorization, 'Bearer secret-token');
    expect(api.lastBetBody?['request_id'], isNotEmpty);

    final rejected = await bridge.handle(<String, dynamic>{
      'method': 'game.bet.place',
      'params': <String, dynamic>{
        'roundId': 88,
        'targetId': 4,
        'amount': 10000,
      },
    });
    expect(rejected['ok'], isFalse);
    expect(api.postPaths, isNot(contains('/games/rounds/88/bets')));
  });

  test('reuses the same bet request id after an ambiguous transport failure', () async {
    final api = _FakeNetworkClient(failFirstBet: true);
    final bridge = GameHostBridge(
      api: api,
      accessToken: 'secret-token',
      gameId: 'jungle_hunt',
      bridgeVersion: 1,
      onClose: () {},
    );
    await bridge.handle(<String, dynamic>{'method': 'game.round.create'});

    final first = await bridge.handle(<String, dynamic>{
      'method': 'game.bet.place',
      'params': <String, dynamic>{
        'roundId': 77,
        'targetId': 4,
        'amount': 10000,
      },
    });
    final second = await bridge.handle(<String, dynamic>{
      'method': 'game.bet.place',
      'params': <String, dynamic>{
        'roundId': 77,
        'targetId': 4,
        'amount': 10000,
      },
    });

    expect(first['ok'], isFalse);
    expect(second['ok'], isTrue);
    expect(api.betRequestIds, hasLength(2));
    expect(api.betRequestIds[0], api.betRequestIds[1]);
  });

  test('close command closes the durable session before leaving the player', () async {
    final api = _FakeNetworkClient();
    var closed = false;
    final bridge = GameHostBridge(
      api: api,
      accessToken: 'secret-token',
      gameId: 'jungle_hunt',
      bridgeVersion: 1,
      onClose: () => closed = true,
    );
    await bridge.initialize();

    final response = await bridge.handle(<String, dynamic>{
      'method': 'host.close',
    });

    expect(response['ok'], isTrue);
    expect(closed, isTrue);
    expect(api.postPaths, contains('/games/sessions/session-123/close'));
  });

  test('rejects methods outside the host bridge allowlist', () async {
    final bridge = GameHostBridge(
      api: _FakeNetworkClient(),
      accessToken: 'secret-token',
      gameId: 'jungle_hunt',
      bridgeVersion: 1,
      onClose: () {},
    );

    final response = await bridge.handle(<String, dynamic>{
      'method': 'network.fetch',
      'params': <String, dynamic>{'url': 'https://evil.example'},
    });

    expect(response['ok'], isFalse);
  });
}

class _FakeNetworkClient implements AppNetworkClient {
  _FakeNetworkClient({this.failFirstBet = false});

  final bool failFirstBet;
  final List<String> postPaths = <String>[];
  final List<String> betRequestIds = <String>[];
  String? lastAuthorization;
  Map<String, dynamic>? roundCreateBody;
  Map<String, dynamic>? lastBetBody;
  var _betAttempts = 0;

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  }) async {
    lastAuthorization = headers['Authorization'];
    if (path == '/games/rounds/77') {
      return <String, dynamic>{'id': 77, 'game_key': 'jungle_hunt'};
    }
    if (path == '/games/global/jungle-hunt/history') {
      return <String, dynamic>{'items': <dynamic>[]};
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async {
    postPaths.add(path);
    lastAuthorization = headers['Authorization'];
    final mapBody = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    if (path == '/games/jungle_hunt/sessions') {
      expect(mapBody['request_id'], isNotEmpty);
      expect(mapBody['bridge_version'], 1);
      return <String, dynamic>{
        'session_id': 'session-123',
        'game_key': 'jungle_hunt',
        'bridge_version': 1,
        'status': 'ACTIVE',
      };
    }
    if (path == '/games/sessions/session-123/close') {
      return <String, dynamic>{
        'session_id': 'session-123',
        'game_key': 'jungle_hunt',
        'bridge_version': 1,
        'status': 'CLOSED',
      };
    }
    if (path == '/games/jungle_hunt/rounds') {
      roundCreateBody = mapBody;
      return <String, dynamic>{'id': 77, 'game_key': 'jungle_hunt'};
    }
    if (path == '/games/rounds/77/bets') {
      lastBetBody = mapBody;
      betRequestIds.add(mapBody['request_id']?.toString() ?? '');
      _betAttempts += 1;
      if (failFirstBet && _betAttempts == 1) {
        throw StateError('simulated transport failure');
      }
      return <String, dynamic>{
        'round_id': 77,
        'accepted_amount': 10000,
      };
    }
    if (path == '/games/rounds/77/settle-test') {
      return <String, dynamic>{'round_id': 77, 'status': 'COMPLETED'};
    }
    throw StateError('Unexpected POST $path');
  }

  @override
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  }) async => throw StateError('Unexpected getList $path');

  @override
  Future<Map<String, dynamic>> patchMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async => throw StateError('Unexpected PATCH $path');

  @override
  Future<Map<String, dynamic>> deleteMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) async => throw StateError('Unexpected DELETE $path');

  @override
  void close() {}
}
