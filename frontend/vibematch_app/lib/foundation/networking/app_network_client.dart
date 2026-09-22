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
