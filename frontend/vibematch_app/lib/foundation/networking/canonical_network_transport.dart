import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/trace_context.dart';
import '../../core/network/vm_api_config.dart';

class NetworkCancellation {
  NetworkCancellation() : _token = CancelToken();

  final CancelToken _token;

  bool get isCancelled => _token.isCancelled;

  void cancel([String reason = 'cancelled']) {
    if (!_token.isCancelled) _token.cancel(reason);
  }
}

class NetworkResponse {
  const NetworkResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.requestId,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;
  final String requestId;

  Object? decodeJson() => body.trim().isEmpty ? null : jsonDecode(body);
}

class NetworkMultipartFile {
  const NetworkMultipartFile({
    required this.field,
    required this.filename,
    required this.bytes,
    this.contentType,
  });

  final String field;
  final String filename;
  final List<int> bytes;
  final String? contentType;
}

class NetworkMultipartBody {
  const NetworkMultipartBody({
    this.fields = const <String, String>{},
    this.files = const <NetworkMultipartFile>[],
  });

  final Map<String, String> fields;
  final List<NetworkMultipartFile> files;
}

typedef NetworkRefreshHandler = Future<String?> Function();

class NetworkAuthCoordinator {
  NetworkAuthCoordinator._();

  static const _tokenKey = 'vm_auth_access_token';
  static String? _cachedToken;
  static NetworkRefreshHandler? _refreshHandler;
  static Future<String?>? _refreshInFlight;

  static void seedAccessToken(String? token) {
    final value = token?.trim();
    _cachedToken = value == null || value.isEmpty ? null : value;
  }

  static void configureRefreshHandler(NetworkRefreshHandler? handler) {
    _refreshHandler = handler;
  }

  static Future<String?> accessToken() async {
    final cached = _cachedToken;
    if (cached != null && cached.isNotEmpty) return cached;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenKey)?.trim();
    if (stored != null && stored.isNotEmpty) {
      _cachedToken = stored;
      return stored;
    }
    return null;
  }

  static Future<String?> refreshOnce() async {
    final handler = _refreshHandler;
    if (handler == null) return null;
    final existing = _refreshInFlight;
    if (existing != null) return existing;
    final future = handler();
    _refreshInFlight = future;
    try {
      final token = (await future)?.trim();
      if (token != null && token.isNotEmpty) {
        _cachedToken = token;
        return token;
      }
      return null;
    } finally {
      _refreshInFlight = null;
    }
  }

  static void clear() {
    _cachedToken = null;
    _refreshInFlight = null;
  }
}

class NetworkMetricsSnapshot {
  const NetworkMetricsSnapshot({
    required this.requests,
    required this.failures,
    required this.retries,
    required this.totalLatencyMs,
  });

  final int requests;
  final int failures;
  final int retries;
  final int totalLatencyMs;

  double get averageLatencyMs =>
      requests == 0 ? 0 : totalLatencyMs / requests;
}

class CanonicalNetworkTransport {
  CanonicalNetworkTransport._()
      : _dio = Dio(
          BaseOptions(
            connectTimeout: AppConstants.connectTimeout,
            receiveTimeout: AppConstants.receiveTimeout,
            sendTimeout: const Duration(minutes: 2),
            validateStatus: (_) => true,
          ),
        );

  static final CanonicalNetworkTransport instance =
      CanonicalNetworkTransport._();

  final Dio _dio;
  final Uuid _uuid = const Uuid();
  final Random _random = Random();
  int _requests = 0;
  int _failures = 0;
  int _retries = 0;
  int _latencyMs = 0;

  NetworkMetricsSnapshot get metrics => NetworkMetricsSnapshot(
        requests: _requests,
        failures: _failures,
        retries: _retries,
        totalLatencyMs: _latencyMs,
      );

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
  }) async {
    final started = DateTime.now();
    _requests += 1;
    final requestId = _header(headers, 'x-request-id') ?? _uuid.v4();
    final baseHeaders = TraceContext.withTraceparent(<String, String>{
      'Accept': 'application/json',
      'X-Request-ID': requestId,
      ...headers,
    });
    if (idempotencyKey != null && idempotencyKey.trim().isNotEmpty) {
      baseHeaders.putIfAbsent('Idempotency-Key', () => idempotencyKey.trim());
    }

    if (attachAuth &&
        _header(baseHeaders, 'authorization') == null &&
        !_isPublicAuthPath(pathOrUrl)) {
      final token = await NetworkAuthCoordinator.accessToken();
      if (token != null) baseHeaders['Authorization'] = 'Bearer $token';
    }

    var authRetried = false;
    var attempt = 0;
    try {
      while (true) {
        attempt += 1;
        try {
          final response = await _send(
            method,
            pathOrUrl,
            queryParameters: queryParameters,
            headers: baseHeaders,
            body: body,
            cancellation: cancellation,
          );

          if (response.statusCode == 401 && !authRetried && attachAuth) {
            final refreshed = await NetworkAuthCoordinator.refreshOnce();
            if (refreshed != null) {
              authRetried = true;
              baseHeaders['Authorization'] = 'Bearer $refreshed';
              _retries += 1;
              continue;
            }
          }

          if (_retryableStatus(response.statusCode) &&
              _canRetry(method, baseHeaders) &&
              attempt < 3) {
            _retries += 1;
            await Future<void>.delayed(_retryDelay(attempt, response.headers));
            continue;
          }

          if (throwOnHttpError &&
              (response.statusCode < 200 || response.statusCode >= 300)) {
            _failures += 1;
            Object? decoded;
            try {
              decoded = response.decodeJson();
            } catch (_) {
              decoded = response.body;
            }
            throw ApiException(
              message: 'Request failed',
              statusCode: response.statusCode,
              body: decoded,
            );
          }
          return response;
        } on DioException catch (error) {
          if (CancelToken.isCancel(error)) rethrow;
          if (_canRetry(method, baseHeaders) && attempt < 3) {
            _retries += 1;
            await Future<void>.delayed(_retryDelay(attempt, const {}));
            continue;
          }
          _failures += 1;
          throw ApiException(
            message: 'Network request failed: ${error.type.name}',
            statusCode: error.response?.statusCode,
            body: error.response?.data,
          );
        }
      }
    } finally {
      _latencyMs += DateTime.now().difference(started).inMilliseconds;
    }
  }

  Future<NetworkResponse> _send(
    String method,
    String pathOrUrl, {
    required Map<String, String?> queryParameters,
    required Map<String, String> headers,
    required Object? body,
    required NetworkCancellation? cancellation,
  }) async {
    final uri = Uri.parse(
      pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')
          ? pathOrUrl
          : VmApiConfig.endpoint(pathOrUrl),
    );
    final query = <String, String>{
      for (final entry in queryParameters.entries)
        if (entry.value != null && entry.value!.trim().isNotEmpty)
          entry.key: entry.value!,
    };
    Object? data = body;
    if (body is NetworkMultipartBody) {
      data = FormData.fromMap(<String, Object?>{
        ...body.fields,
        for (final file in body.files)
          file.field: MultipartFile.fromBytes(
            file.bytes,
            filename: file.filename,
          ),
      });
    }
    final response = await _dio.requestUri<Object?>(
      uri,
      queryParameters: query.isEmpty ? null : query,
      data: data,
      cancelToken: cancellation?._token,
      options: Options(
        method: method.toUpperCase(),
        headers: headers,
        responseType: ResponseType.plain,
        validateStatus: (_) => true,
      ),
    );
    final status = response.statusCode ?? 0;
    return NetworkResponse(
      statusCode: status,
      body: response.data?.toString() ?? '',
      headers: <String, String>{
        for (final entry in response.headers.map.entries)
          entry.key.toLowerCase(): entry.value.join(','),
      },
      requestId: _header(headers, 'x-request-id') ?? '',
    );
  }

  bool _canRetry(String method, Map<String, String> headers) {
    final normalized = method.toUpperCase();
    if (normalized == 'GET' || normalized == 'HEAD' || normalized == 'OPTIONS') {
      return true;
    }
    return _header(headers, 'idempotency-key') != null;
  }

  bool _retryableStatus(int status) =>
      status == 429 || status == 502 || status == 503 || status == 504;

  Duration _retryDelay(int attempt, Map<String, String> headers) {
    final retryAfter = int.tryParse(headers['retry-after'] ?? '');
    if (retryAfter != null && retryAfter >= 0 && retryAfter <= 30) {
      return Duration(seconds: retryAfter);
    }
    final baseMs = min(4000, 250 * (1 << min(attempt, 4)));
    return Duration(milliseconds: baseMs + _random.nextInt(250));
  }

  bool _isPublicAuthPath(String pathOrUrl) =>
      pathOrUrl.contains('/auth/dev-login') ||
      pathOrUrl.contains('/auth/google-login');

  String? _header(Map<String, String> headers, String name) {
    final target = name.toLowerCase();
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == target) return entry.value;
    }
    return null;
  }
}
