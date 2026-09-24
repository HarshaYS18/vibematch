import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
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
    expect(transport, contains('Idempotency-Key'));
    expect(transport, contains('NetworkCancellation'));
  });

  test('foundation http compatibility facade delegates to shared client', () {
    final compat =
        read('lib/foundation/networking/feature_http_compat.dart');
    expect(compat, contains('AppNetworkRuntime.shared.request'));
    expect(compat, isNot(contains("package:http/http.dart")));
    expect(compat, isNot(contains("package:dio/dio.dart")));
  });
}
