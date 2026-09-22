import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/networking/app_network_client.dart';
import 'package:vibematch_app/game_platform/application/game_host_bridge.dart';

void main() {
  test('host context never exposes the app access token', () async {
    final bridge = GameHostBridge(
      api: _FakeNetworkClient(),
      accessToken: 'secret-token',
      gameId: 'jungle_hunt',
      bridgeVersion: 1,
      roomId: '42',
      onClose: () {},
    );

    final response = await bridge.handle(<String, dynamic>{
      'method': 'host.context',
    });

    expect(response['ok'], isTrue);
    expect(response.toString(), isNot(contains('secret-token')));
    expect(
      response['data'],
      <String, dynamic>{
        'gameId': 'jungle_hunt',
        'roomId': '42',
        'bridgeVersion': 1,
      },
    );
  });

  test('creates a round and only permits commands for that session round', () async {
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
  final List<String> postPaths = <String>[];
  String? lastAuthorization;

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
    if (path == '/games/jungle_hunt/rounds') {
      return <String, dynamic>{'id': 77, 'game_key': 'jungle_hunt'};
    }
    if (path == '/games/rounds/77/bets') {
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
