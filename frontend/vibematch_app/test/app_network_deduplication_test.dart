import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vibematch_app/foundation/networking/app_network_client.dart';

class _CountingClient implements AppNetworkClient {
  int mapReads = 0;
  final Completer<Map<String, dynamic>> mapCompleter = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> getMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}}) {
    mapReads += 1;
    return mapCompleter.future;
  }

  @override
  Future<List<dynamic>> getList(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}}) async => <dynamic>[];
  @override
  Future<Map<String, dynamic>> postMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body}) async => <String, dynamic>{};
  @override
  Future<Map<String, dynamic>> patchMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body}) async => <String, dynamic>{};
  @override
  Future<Map<String, dynamic>> deleteMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body}) async => <String, dynamic>{};
  @override
  void close() {}
}

void main() {
  test('identical in-flight map reads are deduplicated', () async {
    final inner = _CountingClient();
    final client = DeduplicatingAppNetworkClient(inner);
    final first = client.getMap('/rooms/trending');
    final second = client.getMap('/rooms/trending');
    expect(inner.mapReads, 1);
    inner.mapCompleter.complete(<String, dynamic>{'ok': true});
    expect(await first, <String, dynamic>{'ok': true});
    expect(await second, <String, dynamic>{'ok': true});
  });

  test('auth headers are part of the dedupe key', () {
    final inner = _CountingClient();
    final client = DeduplicatingAppNetworkClient(inner);
    client.getMap('/users/me', headers: const <String, String>{'Authorization': 'Bearer a'});
    client.getMap('/users/me', headers: const <String, String>{'Authorization': 'Bearer b'});
    expect(inner.mapReads, 2);
  });
}
