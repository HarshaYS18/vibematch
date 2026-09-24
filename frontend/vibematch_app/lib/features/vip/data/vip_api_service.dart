import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/vip_models.dart';

class VipApiService {
  const VipApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<VipCenterPayload> loadMyVipCenter() async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again to load VIP details.');
    }

    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/economy/me')),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to load VIP details'));
    }

    return VipCenterPayload.fromEconomyJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  String _errorMessage(http.Response response, {required String fallback}) {
    final body = response.body.trim();
    if (body.isEmpty) return '$fallback (${response.statusCode})';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) return detail.trim();
        if (detail != null) return detail.toString();
      }
    } catch (_) {
      return body;
    }
    return '$fallback (${response.statusCode})';
  }
}
