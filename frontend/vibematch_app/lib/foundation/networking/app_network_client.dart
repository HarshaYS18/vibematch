import '../../core/network/api_client.dart';

abstract interface class AppNetworkClient {
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  });

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  });

  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  });

  Future<Map<String, dynamic>> patchMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  });

  Future<Map<String, dynamic>> deleteMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  });

  void close();
}

class ApiClientNetworkAdapter implements AppNetworkClient {
  ApiClientNetworkAdapter({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  }) =>
      _apiClient.getMap(
        path,
        queryParameters: queryParameters,
        headers: headers,
      );

  @override
  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
  }) =>
      _apiClient.getList(
        path,
        queryParameters: queryParameters,
        headers: headers,
      );

  @override
  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) =>
      _apiClient.postMap(
        path,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
      );

  @override
  Future<Map<String, dynamic>> patchMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) =>
      _apiClient.patchMap(
        path,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
      );

  @override
  Future<Map<String, dynamic>> deleteMap(
    String path, {
    Map<String, String?> queryParameters = const <String, String?>{},
    Map<String, String> headers = const <String, String>{},
    Object? body,
  }) =>
      _apiClient.deleteMap(
        path,
        queryParameters: queryParameters,
        headers: headers,
        body: body,
      );

  @override
  void close() => _apiClient.close();
}


class DeduplicatingAppNetworkClient implements AppNetworkClient {
  DeduplicatingAppNetworkClient(this._inner);

  final AppNetworkClient _inner;
  final Map<String, Future<Map<String, dynamic>>> _mapReads = <String, Future<Map<String, dynamic>>>{};
  final Map<String, Future<List<dynamic>>> _listReads = <String, Future<List<dynamic>>>{};

  String _key(String path, Map<String, String?> queryParameters, Map<String, String> headers) {
    final query = queryParameters.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final headerEntries = headers.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return <Object>[
      path,
      for (final entry in query) '${entry.key}=${entry.value ?? ''}',
      '|',
      for (final entry in headerEntries) '${entry.key}=${entry.value}',
    ].join('&');
  }

  @override
  Future<Map<String, dynamic>> getMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}}) {
    final key = _key(path, queryParameters, headers);
    final existing = _mapReads[key];
    if (existing != null) return existing;
    final future = _inner.getMap(path, queryParameters: queryParameters, headers: headers);
    _mapReads[key] = future;
    future.then<void>(
      (_) => _mapReads.remove(key),
      onError: (Object _, StackTrace __) {
        _mapReads.remove(key);
      },
    );
    return future;
  }

  @override
  Future<List<dynamic>> getList(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}}) {
    final key = _key(path, queryParameters, headers);
    final existing = _listReads[key];
    if (existing != null) return existing;
    final future = _inner.getList(path, queryParameters: queryParameters, headers: headers);
    _listReads[key] = future;
    future.then<void>(
      (_) => _listReads.remove(key),
      onError: (Object _, StackTrace __) {
        _listReads.remove(key);
      },
    );
    return future;
  }

  @override
  Future<Map<String, dynamic>> postMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body}) => _inner.postMap(path, queryParameters: queryParameters, headers: headers, body: body);
  @override
  Future<Map<String, dynamic>> patchMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body}) => _inner.patchMap(path, queryParameters: queryParameters, headers: headers, body: body);
  @override
  Future<Map<String, dynamic>> deleteMap(String path, {Map<String, String?> queryParameters = const <String, String?>{}, Map<String, String> headers = const <String, String>{}, Object? body}) => _inner.deleteMap(path, queryParameters: queryParameters, headers: headers, body: body);

  @override
  void close() {
    _mapReads.clear();
    _listReads.clear();
    _inner.close();
  }
}
