import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const rawHttpImport = 'package:' 'http/http.dart';
  final root = Directory.current.path.endsWith('vibematch_app')
      ? Directory.current
      : Directory('frontend/vibematch_app');

  String read(String relative) =>
      File('${root.path}/$relative').readAsStringSync();

  test('canonical app network transport is Dio-backed', () {
    final client = read('lib/foundation/networking/app_network_client.dart');
    final transport =
        read('lib/foundation/networking/canonical_network_transport.dart');
    expect(client, contains('DioAppNetworkClient'));
    expect(transport, contains("package:dio/dio.dart"));
    expect(transport, contains('X-Request-ID'));
    expect(transport, contains('TraceContext.withTraceparent'));
    expect(transport, contains('NetworkAuthCoordinator.refreshOnce'));
    expect(transport, contains('AppKeyValueStore'));
    expect(transport, isNot(contains('SharedPreferences.getInstance')));
    expect(transport, contains('Idempotency-Key'));
    expect(transport, contains('NetworkCancellation'));
  });

  test('deprecated ApiClient compatibility alias stays removed', () {
    expect(File('${root.path}/lib/core/network/api_client.dart').existsSync(), isFalse);
  });

  test('foundation http compatibility facade delegates to shared client', () {
    final compat =
        read('lib/foundation/networking/feature_http_compat.dart');
    expect(compat, contains('AppNetworkRuntime.shared.request'));
    expect(compat, isNot(contains(rawHttpImport)));
    expect(compat, isNot(contains("package:dio/dio.dart")));
  });

  test('specialized foundation transports delegate to canonical Dio owner', () {
    final upload =
        read('lib/foundation/networking/direct_upload_transport.dart');
    final assets =
        read('lib/foundation/networking/remote_asset_client.dart');

    expect(upload, contains('CanonicalNetworkTransport.instance'));
    expect(upload, contains('_transport.putStream('));
    expect(upload, isNot(contains(rawHttpImport)));
    expect(assets, contains('CanonicalNetworkTransport.instance'));
    expect(assets, contains('_transport.getBytes('));
    expect(assets, isNot(contains(rawHttpImport)));
  });

  test('features cannot bypass the canonical transport', () {
    final lib = Directory('${root.path}/lib');
    final violations = <String>[];
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final source = entity.readAsStringSync();
      final foundationNetworking = path.contains('/foundation/networking/');

      if (!foundationNetworking &&
          source.contains(rawHttpImport)) {
        violations.add('$path imports package:http');
      }
      if (!path.endsWith('/foundation/networking/canonical_network_transport.dart') &&
          source.contains("package:dio/dio.dart")) {
        violations.add('$path imports Dio directly');
      }
      if (!foundationNetworking && RegExp(r'\bHttpClient\b').hasMatch(source)) {
        violations.add('$path uses HttpClient directly');
      }
      if (source.contains('core/network/api_client.dart')) {
        violations.add('$path imports decommissioned ApiClient');
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'REST must flow through AppNetworkClient -> Dio.\n'
          '${violations.join('\n')}',
    );
  });

}
