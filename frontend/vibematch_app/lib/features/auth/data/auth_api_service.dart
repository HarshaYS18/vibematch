import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../models/current_user.dart';

class AuthApiService {
  const AuthApiService();

  static String get baseUrl => VmApiConfig.baseUrl;

  static String? _cachedAccessToken;
  static CurrentUser? _cachedUser;
  static String? _cachedDeviceId;

  Future<String> getCurrentDeviceId() async {
    final existingDeviceId = _cachedDeviceId;
    if (existingDeviceId != null && existingDeviceId.trim().isNotEmpty) {
      return existingDeviceId;
    }

    final generatedDeviceId = 'vm-dev-${DateTime.now().millisecondsSinceEpoch.toString()}';
    _cachedDeviceId = generatedDeviceId;
    return generatedDeviceId;
  }

  Future<AuthLoginResult> devLogin({
    required String email,
    String? username,
    String? displayName,
    String? deviceId,
  }) async {
    _cachedAccessToken = null;
    _cachedUser = null;

    final loginUri = Uri.parse(VmApiConfig.endpoint('/auth/dev-login'));
    final safeEmail = email.trim().toLowerCase();
    final safeUsername = username?.trim();
    final safeDisplayName = displayName?.trim();
    final safeDeviceId = deviceId?.trim();
    final resolvedDeviceId = safeDeviceId == null || safeDeviceId.isEmpty ? await getCurrentDeviceId() : safeDeviceId;

    final loginResponse = await http.post(
      loginUri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': safeEmail,
        if (safeUsername != null && safeUsername.isNotEmpty) 'username': safeUsername,
        if (safeDisplayName != null && safeDisplayName.isNotEmpty) 'display_name': safeDisplayName,
        'device_id': resolvedDeviceId,
      }),
    );

    if (loginResponse.statusCode < 200 || loginResponse.statusCode >= 300) {
      throw Exception('Login failed (${loginResponse.statusCode}): ${loginResponse.body}');
    }

    final decoded = jsonDecode(loginResponse.body) as Map<String, dynamic>;
    final accessToken = decoded['access_token'] as String?;
    final tokenType = decoded['token_type'] as String? ?? 'bearer';

    if (accessToken == null || accessToken.trim().isEmpty) {
      throw Exception('Login response did not include access_token.');
    }

    _cachedAccessToken = accessToken;
    _cachedDeviceId = resolvedDeviceId;

    final user = await getCurrentUser(accessToken: accessToken, forceRefresh: true);
    _cachedUser = user;
    AuthUserRealtimeService.instance.publish(user);

    return AuthLoginResult(accessToken: accessToken, tokenType: tokenType, user: user);
  }

  Future<AuthLoginResult> googleLogin({
    required String idToken,
    String? deviceId,
  }) async {
    _cachedAccessToken = null;
    _cachedUser = null;

    final safeToken = idToken.trim();
    if (safeToken.isEmpty) {
      throw Exception('Google login failed: missing Google ID token.');
    }

    final safeDeviceId = deviceId?.trim();
    final resolvedDeviceId = safeDeviceId == null || safeDeviceId.isEmpty ? await getCurrentDeviceId() : safeDeviceId;

    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/auth/google-login')),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_token': safeToken,
        'device_id': resolvedDeviceId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Google login failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final accessToken = decoded['access_token'] as String?;
    final tokenType = decoded['token_type'] as String? ?? 'bearer';
    if (accessToken == null || accessToken.trim().isEmpty) {
      throw Exception('Google login response did not include access_token.');
    }

    _cachedAccessToken = accessToken;
    _cachedDeviceId = resolvedDeviceId;
    final user = await getCurrentUser(accessToken: accessToken, forceRefresh: true);
    _cachedUser = user;
    AuthUserRealtimeService.instance.publish(user);
    return AuthLoginResult(accessToken: accessToken, tokenType: tokenType, user: user);
  }

  Future<CurrentUser> getCurrentUser({String? accessToken, bool forceRefresh = false}) async {
    final token = accessToken ?? _cachedAccessToken;

    if (token == null || token.trim().isEmpty) {
      if (!forceRefresh && _cachedUser != null) return _cachedUser!;
      throw Exception('No access token available. Please login again.');
    }

    if (!forceRefresh && accessToken == null && _cachedUser != null) {
      return _cachedUser!;
    }

    final uri = Uri.parse(VmApiConfig.endpoint('/users/me'));
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load current user (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final user = CurrentUser.fromJson(decoded);

    _cachedAccessToken = token;
    _cachedUser = user;
    AuthUserRealtimeService.instance.publish(user);
    return user;
  }

  Future<CurrentUser> updateProfile({
    required String displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    final token = _cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No access token available. Please login again.');
    }

    final safeName = displayName.trim();
    if (safeName.isEmpty) throw Exception('Name is required.');

    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/users/me/profile')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'display_name': safeName,
        'bio': bio?.trim() ?? '',
        if (avatarUrl != null) 'avatar_url': avatarUrl.trim(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to update profile'));
    }

    final user = CurrentUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    _cachedUser = user;
    AuthUserRealtimeService.instance.publish(user);
    return user;
  }

  Future<void> logout() async {
    _cachedAccessToken = null;
    _cachedUser = null;
  }

  String? get cachedAccessToken => _cachedAccessToken;

  CurrentUser? get cachedUser => _cachedUser;

  String _errorMessage(http.Response response, {required String fallback}) {
    final body = response.body.trim();
    if (body.isEmpty) return '$fallback (${response.statusCode})';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString().trim();
        if (detail != null && detail.isNotEmpty) return detail;
      }
    } catch (_) {
      return body;
    }
    return '$fallback (${response.statusCode})';
  }
}

class AuthUserRealtimeService {
  AuthUserRealtimeService._();

  static final AuthUserRealtimeService instance = AuthUserRealtimeService._();

  final StreamController<CurrentUser> _controller = StreamController<CurrentUser>.broadcast();

  Stream<CurrentUser> get users => _controller.stream;

  void publish(CurrentUser user) {
    _controller.add(user);
  }
}

class AuthLoginResult {
  const AuthLoginResult({required this.accessToken, required this.tokenType, required this.user});

  final String accessToken;
  final String tokenType;
  final CurrentUser user;
}
