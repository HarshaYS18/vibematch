import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/vip_wallet_models.dart';

class VipAdminApiService {
  const VipAdminApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<UserVipSummary> getUserVipStatus(int publicUserId) async {
    final token = _token();
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/admin/users/vip/users/$publicUserId')),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load VIP/SVIP status (${response.statusCode}): ${response.body}');
    }
    return UserVipSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<UserVipSummary> updateUserVipStatus({
    required int publicUserId,
    required int vipLevel,
    required int svipLevel,
    required bool vipIsActive,
    required bool svipIsActive,
    required int svipDays,
    required String reason,
  }) async {
    final token = _token();
    final mutation = <String, dynamic>{
      'vip_level': vipLevel,
      'svip_level': svipLevel,
      'vip_is_active': vipIsActive,
      'svip_is_active': svipIsActive,
      'svip_days': svipDays,
      'reason': reason.trim(),
    };
    final fingerprint = sha256.convert(utf8.encode(jsonEncode(mutation))).toString();
    final pendingKey = 'vip_admin_pending_request_$publicUserId:$fingerprint';
    final preferences = await SharedPreferences.getInstance();
    final requestId =
        preferences.getString(pendingKey) ?? const Uuid().v4();
    await preferences.setString(pendingKey, requestId);

    try {
      final response = await http.put(
        Uri.parse(VmApiConfig.endpoint('/admin/users/vip/users/$publicUserId')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(<String, dynamic>{
          'request_id': requestId,
          ...mutation,
        }),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        // 4xx is a deterministic rejection; 5xx remains ambiguous and keeps the
        // same request ID for a safe retry.
        if (response.statusCode >= 400 && response.statusCode < 500) {
          await preferences.remove(pendingKey);
        }
        throw Exception(
          'Failed to update VIP/SVIP status (${response.statusCode}): ${response.body}',
        );
      }
      await preferences.remove(pendingKey);
      return UserVipSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (_) {
      rethrow;
    }
  }

  String _token() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before using VIP/SVIP controls.');
    }
    return token;
  }
}
