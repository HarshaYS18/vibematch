import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../models/current_user.dart';
import 'auth_api_service.dart';

class GoogleWebAuthFallbackService {
  const GoogleWebAuthFallbackService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<AuthLoginResult> loginWithGoogleCredential({
    String? idToken,
    String? googleAccessToken,
  }) async {
    final safeIdToken = idToken?.trim() ?? '';
    final safeGoogleAccessToken = googleAccessToken?.trim() ?? '';
    if (safeIdToken.isEmpty && safeGoogleAccessToken.isEmpty) {
      throw Exception('Google did not return a usable login token.');
    }

    final deviceId = await authApiService.getCurrentDeviceId();
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/auth/google-login')),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (safeIdToken.isNotEmpty) 'id_token': safeIdToken,
        if (safeGoogleAccessToken.isNotEmpty) 'access_token': safeGoogleAccessToken,
        'device_id': deviceId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Google login failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final appAccessToken = decoded['access_token'] as String?;
    final tokenType = decoded['token_type'] as String? ?? 'bearer';
    if (appAccessToken == null || appAccessToken.trim().isEmpty) {
      throw Exception('Google login response did not include app access token.');
    }

    final user = await authApiService.getCurrentUser(
      accessToken: appAccessToken,
      forceRefresh: true,
    );
    await authApiService.persistCurrentUser(user);
    return AuthLoginResult(
      accessToken: appAccessToken,
      tokenType: tokenType,
      user: user,
    );
  }
}
