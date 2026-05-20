import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/vm_api_config.dart';
import '../../../core/notifications/vm_push_notification_service.dart';
import '../../../core/session/vm_session_cleanup_service.dart';
import '../models/current_user.dart';
import '../models/current_user_master_state_mapper.dart';

class AuthApiService {
  const AuthApiService();

  static const String _tokenKey = 'vm_auth_access_token';
  static const String _userJsonKey = 'vm_auth_user_json';
  static const String _deviceIdKey = 'vm_auth_device_id';

  static String get baseUrl => VmApiConfig.baseUrl;

  static String? _cachedAccessToken;
  static CurrentUser? _cachedUser;
  static String? _cachedDeviceId;

  Future<String> getCurrentDeviceId() async {
    final existingDeviceId = _cachedDeviceId;
    if (existingDeviceId != null && existingDeviceId.trim().isNotEmpty) {
      return existingDeviceId;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedDeviceId = prefs.getString(_deviceIdKey);
    if (savedDeviceId != null && savedDeviceId.trim().isNotEmpty) {
      _cachedDeviceId = savedDeviceId;
      return savedDeviceId;
    }

    final generatedDeviceId = 'vm-dev-${DateTime.now().millisecondsSinceEpoch.toString()}';
    _cachedDeviceId = generatedDeviceId;
    await prefs.setString(_deviceIdKey, generatedDeviceId);
    return generatedDeviceId;
  }

  Future<void> restoreSavedSession() async {
    final prefs = await SharedPreferences.getInstance();

    _cachedAccessToken = prefs.getString(_tokenKey);
    _cachedDeviceId = prefs.getString(_deviceIdKey);

    final savedUserJson = prefs.getString(_userJsonKey);
    if (savedUserJson != null && savedUserJson.trim().isNotEmpty) {
      try {
        _cachedUser = CurrentUser.fromJson(jsonDecode(savedUserJson) as Map<String, dynamic>);
        AuthUserRealtimeService.instance.publish(_cachedUser!);
      } catch (_) {
        _cachedUser = null;
      }
    }
  }

  Future<void> _persistSession({
    required String accessToken,
    required CurrentUser user,
    required String deviceId,
  }) async {
    _cachedAccessToken = accessToken;
    _cachedUser = user;
    _cachedDeviceId = deviceId;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setString(_userJsonKey, jsonEncode(user.toJson()));
  }

  Future<void> persistCurrentUser(CurrentUser user) async {
    _cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userJsonKey, jsonEncode(user.toJson()));
    AuthUserRealtimeService.instance.publish(user);
  }

  Future<AuthLoginResult> devLogin({
    required String email,
    String? username,
    String? displayName,
    String? deviceId,
  }) async {
    await VmSessionCleanupService.clearUserScopedState(reason: 'dev login account switch');
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
    await _persistSession(accessToken: accessToken, user: user, deviceId: resolvedDeviceId);
    AuthUserRealtimeService.instance.publish(user);

    return AuthLoginResult(accessToken: accessToken, tokenType: tokenType, user: user);
  }

  Future<AuthLoginResult> googleLogin({
    required String idToken,
    String? deviceId,
  }) async {
    await VmSessionCleanupService.clearUserScopedState(reason: 'google login account switch');
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
    await _persistSession(accessToken: accessToken, user: user, deviceId: resolvedDeviceId);
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

    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/users/me/master-state')),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load backend master user state (${response.statusCode}): ${response.body}');
    }

    final user = currentUserFromMasterStateJson(jsonDecode(response.body) as Map<String, dynamic>);

    final deviceId = _cachedDeviceId ?? await getCurrentDeviceId();
    await _persistSession(accessToken: token, user: user, deviceId: deviceId);
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

    final user = await getCurrentUser(accessToken: token, forceRefresh: true);
    await persistCurrentUser(user);
    return user;
  }

  Future<void> logout() async {
    await VmPushNotificationService.instance.deleteCurrentTokenOnLogout();
    await VmSessionCleanupService.clearUserScopedState(reason: 'logout');
    _cachedAccessToken = null;
    _cachedUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userJsonKey);
    AuthUserRealtimeService.instance.publishSignedOut();
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
  final StreamController<void> _signedOutController = StreamController<void>.broadcast();

  Stream<CurrentUser> get users => _controller.stream;
  Stream<void> get signedOut => _signedOutController.stream;

  void publish(CurrentUser user) {
    _controller.add(user);
  }

  void publishSignedOut() {
    _signedOutController.add(null);
  }
}

class AuthLoginResult {
  const AuthLoginResult({required this.accessToken, required this.tokenType, required this.user});

  final String accessToken;
  final String tokenType;
  final CurrentUser user;
}
