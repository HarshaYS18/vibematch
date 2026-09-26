import 'dart:convert';

import '../../core/network/api_exception.dart';
import 'canonical_network_transport.dart';

export 'canonical_network_transport.dart'
    show
        NetworkCancellation,
        NetworkMetricsSnapshot,
        NetworkAuthCoordinator,
        NetworkMultipartBody,
        NetworkMultipartFile,
        NetworkResponse;

abstract interface class AppNetworkClient {
  Future<NetworkResponse> request(
    String method,
    String pathOrUrl, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
    NetworkCancellation? cancellation,
    String? idempotencyKey,
    bool throwOnHttpError = true,
    bool attachAuth = true,
  });

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    NetworkCancellation? cancellation,
  });

  Future<Map<String, dynamic>?> getOptionalMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    NetworkCancellation? cancellation,
  });

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    NetworkCancellation? cancellation,
  });

  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
    NetworkCancellation? cancellation,
    String? idempotencyKey,
  });

  Future<Map<String, dynamic>> putMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
    NetworkCancellation? cancellation,
    String? idempotencyKey,
  });

  Future<Map<String, dynamic>> patchMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
    NetworkCancellation? cancellation,
    String? idempotencyKey,
  });

  Future<Map<String, dynamic>> deleteMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
    NetworkCancellation? cancellation,
    String? idempotencyKey,
  });

  void close();
}

class DioAppNetworkClient implements AppNetworkClient {
  DioAppNetworkClient({CanonicalNetworkTransport? transport})
      : _transport = transport ?? CanonicalNetworkTransport.instance;

  final CanonicalNetworkTransport _transport;

  @override
  Future<NetworkResponse> request(
    String method,
    String pathOrUrl, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
    NetworkCancellation? cancellation,
    String? idempotencyKey,
    bool throwOnHttpError = true,
    bool attachAuth = true,
  }) =>
      _transport.request(
        method,
        pathOrUrl,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
        cancellation: cancellation,
        idempotencyKey: idempotencyKey,
        throwOnHttpError: throwOnHttpError,
        attachAuth: attachAuth,
      );

  Future<Object?> _json(
    String method,
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
    NetworkCancellation? cancellation,
    String? idempotencyKey,
  }) async {
    final response = await request(
      method,
      path,
      queryParameters: queryParameters,
      headers: <String, String>{
        if (body != null) 'Content-Type': 'application/json',
        ...headers,
      },
      body: body == null ? null : jsonEncode(body),
      cancellation: cancellation,
      idempotencyKey: idempotencyKey,
    );
    return response.body.trim().isEmpty ? null : jsonDecode(response.body);
  }

  @override
  Future<Map<String, dynamic>> getMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, NetworkCancellation? cancellation}) async {
    final value = await _json('GET', path, queryParameters: queryParameters, headers: headers, cancellation: cancellation);
    if (value is Map<String, dynamic>) return value;
    throw ApiException(message: 'Expected a JSON object response', body: value);
  }

  @override
  Future<Map<String, dynamic>?> getOptionalMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, NetworkCancellation? cancellation}) async {
    final response = await request(
      'GET',
      path,
      queryParameters: queryParameters,
      headers: headers,
      cancellation: cancellation,
    );
    if (response.body.trim().isEmpty) return null;
    final value = jsonDecode(response.body);
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    throw ApiException(
      message: 'Expected a nullable JSON object response',
      statusCode: response.statusCode,
      body: value,
    );
  }

  @override
  Future<List<dynamic>> getList(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, NetworkCancellation? cancellation}) async {
    final value = await _json('GET', path, queryParameters: queryParameters, headers: headers, cancellation: cancellation);
    if (value is List<dynamic>) return value;
    throw ApiException(message: 'Expected a JSON list response', body: value);
  }

  @override
  Future<Map<String, dynamic>> postMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) =>
      _mapWrite('POST', path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);

  @override
  Future<Map<String, dynamic>> putMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) =>
      _mapWrite('PUT', path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);

  @override
  Future<Map<String, dynamic>> patchMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) =>
      _mapWrite('PATCH', path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);

  @override
  Future<Map<String, dynamic>> deleteMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) =>
      _mapWrite('DELETE', path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);

  Future<Map<String, dynamic>> _mapWrite(String method, String path, {required Map<String, String?> queryParameters, required Map<String, String> headers, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) async {
    final value = await _json(method, path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);
    if (value is Map<String, dynamic>) return value;
    throw ApiException(message: 'Expected a JSON object response', body: value);
  }

  @override
  void close() {
    // Canonical transport is intentionally process-scoped and reused.
  }
}

class ApiClientNetworkAdapter extends DioAppNetworkClient {
  ApiClientNetworkAdapter({super.transport});
}

class AppNetworkRuntime {
  AppNetworkRuntime._();

  static final AppNetworkClient shared = DioAppNetworkClient();
  static NetworkMetricsSnapshot get metrics =>
      CanonicalNetworkTransport.instance.metrics;
}

class DeduplicatingAppNetworkClient implements AppNetworkClient {
  DeduplicatingAppNetworkClient(this._inner);

  final AppNetworkClient _inner;
  final Map<String, Future<Map<String, dynamic>>> _mapReads = {};
  final Map<String, Future<Map<String, dynamic>?>> _optionalMapReads = {};
  final Map<String, Future<List<dynamic>>> _listReads = {};

  String _key(String path, Map<String, String?> query, Map<String, String> headers) {
    final q = query.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final h = headers.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return <Object>[path, ...q.map((e) => '${e.key}=${e.value ?? ''}'), '|', ...h.map((e) => '${e.key}=${e.value}')].join('&');
  }

  @override
  Future<NetworkResponse> request(String method, String pathOrUrl, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey, bool throwOnHttpError = true, bool attachAuth = true}) =>
      _inner.request(method, pathOrUrl, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey, throwOnHttpError: throwOnHttpError, attachAuth: attachAuth);

  @override
  Future<Map<String, dynamic>> getMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, NetworkCancellation? cancellation}) {
    final key = _key(path, queryParameters, headers);
    return _mapReads.putIfAbsent(key, () {
      final future = _inner.getMap(path, queryParameters: queryParameters, headers: headers, cancellation: cancellation);
      future.whenComplete(() => _mapReads.remove(key));
      return future;
    });
  }

  @override
  Future<Map<String, dynamic>?> getOptionalMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, NetworkCancellation? cancellation}) {
    final key = _key(path, queryParameters, headers);
    return _optionalMapReads.putIfAbsent(key, () {
      final future = _inner.getOptionalMap(path, queryParameters: queryParameters, headers: headers, cancellation: cancellation);
      future.whenComplete(() => _optionalMapReads.remove(key));
      return future;
    });
  }

  @override
  Future<List<dynamic>> getList(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, NetworkCancellation? cancellation}) {
    final key = _key(path, queryParameters, headers);
    return _listReads.putIfAbsent(key, () {
      final future = _inner.getList(path, queryParameters: queryParameters, headers: headers, cancellation: cancellation);
      future.whenComplete(() => _listReads.remove(key));
      return future;
    });
  }

  @override
  Future<Map<String, dynamic>> postMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) => _inner.postMap(path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);
  @override
  Future<Map<String, dynamic>> putMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) => _inner.putMap(path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);
  @override
  Future<Map<String, dynamic>> patchMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) => _inner.patchMap(path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);
  @override
  Future<Map<String, dynamic>> deleteMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body, NetworkCancellation? cancellation, String? idempotencyKey}) => _inner.deleteMap(path, queryParameters: queryParameters, headers: headers, body: body, cancellation: cancellation, idempotencyKey: idempotencyKey);

  @override
  void close() {
    _mapReads.clear();
    _optionalMapReads.clear();
    _listReads.clear();
    _inner.close();
  }
}
