import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/vip_wallet_models.dart';

class VipAdminApiService {
  const VipAdminApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<UserVipSummary> getUserVipStatus(int publicUserId) async {
    final token = _token();
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/admin/vip/users/$publicUserId')),
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
    final response = await http.put(
      Uri.parse(VmApiConfig.endpoint('/admin/vip/users/$publicUserId')),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'vip_level': vipLevel,
        'svip_level': svipLevel,
        'vip_is_active': vipIsActive,
        'svip_is_active': svipIsActive,
        'svip_days': svipDays,
        'reason': reason.trim(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to update VIP/SVIP status (${response.statusCode}): ${response.body}');
    }
    return UserVipSummary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  String _token() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before using VIP/SVIP controls.');
    }
    return token;
  }
}
