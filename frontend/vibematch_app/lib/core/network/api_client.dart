import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
    : _baseUrlOverride = baseUrl,
      _httpClient = httpClient ?? http.Client();

  final String? _baseUrlOverride;
  final http.Client _httpClient;

  String get baseUrl {
    return _baseUrlOverride ?? AppConstants.webApiBaseUrl;
  }

  Uri _buildUri(
    String path, {
    Map<String, String?> queryParameters = const {},
  }) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');

    final cleanQuery = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null && value.trim().isNotEmpty) {
        cleanQuery[key] = value;
      }
    });

    if (cleanQuery.isEmpty) return uri;
    return uri.replace(queryParameters: cleanQuery);
  }

  Future<Map<String, dynamic>> getMap(
    String path, {
    Map<String, String?> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    final response = await _httpClient
        .get(
          _buildUri(path, queryParameters: queryParameters),
          headers: {'Accept': 'application/json', ...headers},
        )
        .timeout(AppConstants.receiveTimeout);

    final decodedBody = _decodeResponseBody(response);

    if (decodedBody is Map<String, dynamic>) return decodedBody;

    throw ApiException(
      message: 'Expected a JSON object response',
      statusCode: response.statusCode,
      body: decodedBody,
    );
  }

  Future<Map<String, dynamic>?> getOptionalMap(
    String path, {
    Map<String, String?> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    final response = await _httpClient
        .get(
          _buildUri(path, queryParameters: queryParameters),
          headers: {'Accept': 'application/json', ...headers},
        )
        .timeout(AppConstants.receiveTimeout);

    final decodedBody = _decodeResponseBody(response);

    if (decodedBody == null) return null;
    if (decodedBody is Map<String, dynamic>) return decodedBody;

    throw ApiException(
      message: 'Expected a nullable JSON object response',
      statusCode: response.statusCode,
      body: decodedBody,
    );
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String?> queryParameters = const {},
    Map<String, String> headers = const {},
  }) async {
    final response = await _httpClient
        .get(
          _buildUri(path, queryParameters: queryParameters),
          headers: {'Accept': 'application/json', ...headers},
        )
        .timeout(AppConstants.receiveTimeout);

    final decodedBody = _decodeResponseBody(response);

    if (decodedBody is List<dynamic>) return decodedBody;

    throw ApiException(
      message: 'Expected a JSON list response',
      statusCode: response.statusCode,
      body: decodedBody,
    );
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, String?> queryParameters = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final response = await _httpClient
        .post(
          _buildUri(path, queryParameters: queryParameters),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ...headers,
          },
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(AppConstants.receiveTimeout);

    final decodedBody = _decodeResponseBody(response);

    if (decodedBody is Map<String, dynamic>) return decodedBody;

    throw ApiException(
      message: 'Expected a JSON object response',
      statusCode: response.statusCode,
      body: decodedBody,
    );
  }

  Future<Map<String, dynamic>> patchMap(
    String path, {
    Map<String, String?> queryParameters = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final response = await _httpClient
        .patch(
          _buildUri(path, queryParameters: queryParameters),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ...headers,
          },
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(AppConstants.receiveTimeout);

    final decodedBody = _decodeResponseBody(response);

    if (decodedBody is Map<String, dynamic>) return decodedBody;

    throw ApiException(
      message: 'Expected a JSON object response',
      statusCode: response.statusCode,
      body: decodedBody,
    );
  }

  Future<Map<String, dynamic>> deleteMap(
    String path, {
    Map<String, String?> queryParameters = const {},
    Map<String, String> headers = const {},
    Object? body,
  }) async {
    final response = await _httpClient
        .delete(
          _buildUri(path, queryParameters: queryParameters),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ...headers,
          },
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(AppConstants.receiveTimeout);

    final decodedBody = _decodeResponseBody(response);

    if (decodedBody is Map<String, dynamic>) return decodedBody;

    throw ApiException(
      message: 'Expected a JSON object response',
      statusCode: response.statusCode,
      body: decodedBody,
    );
  }

  Future<Map<String, dynamic>> getHealthStatus() {
    return getMap('/health');
  }

  Object? _decodeResponseBody(http.Response response) {
    final decodedBody = response.body.isEmpty
        ? null
        : jsonDecode(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: 'Request failed',
        statusCode: response.statusCode,
        body: decodedBody,
      );
    }

    return decodedBody;
  }

  void close() {
    _httpClient.close();
  }
}
