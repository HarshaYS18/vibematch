import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class GiftCatalogAdminApiService {
  const GiftCatalogAdminApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<Map<String, dynamic>> getCatalog() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/admin/economy/gifts/catalog')),
      headers: await _headers(),
    );
    _throwIfBad(response, 'Failed to load gift catalog admin');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> seedDefaults({required String reason}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/admin/economy/gifts/catalog/seed-defaults')),
      headers: await _headers(),
      body: jsonEncode({'reason': reason.trim()}),
    );
    _throwIfBad(response, 'Failed to seed gift catalog');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setCategoryEnabled({
    required String categoryKey,
    required bool enabled,
    required String reason,
  }) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/admin/economy/gifts/categories/$categoryKey/enabled')),
      headers: await _headers(),
      body: jsonEncode({'is_enabled': enabled, 'reason': reason.trim()}),
    );
    _throwIfBad(response, 'Failed to update gift category');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setGiftEnabled({
    required String giftId,
    required bool enabled,
    required String reason,
  }) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/admin/economy/gifts/items/$giftId/enabled')),
      headers: await _headers(),
      body: jsonEncode({'is_enabled': enabled, 'reason': reason.trim()}),
    );
    _throwIfBad(response, 'Failed to update gift item');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upsertCategory({
    required String key,
    required String label,
    required bool enabled,
    required int sortOrder,
    required String reason,
  }) async {
    final response = await http.put(
      Uri.parse(VmApiConfig.endpoint('/admin/economy/gifts/categories/$key')),
      headers: await _headers(),
      body: jsonEncode({
        'key': key.trim(),
        'label': label.trim(),
        'is_enabled': enabled,
        'sort_order': sortOrder,
        'reason': reason.trim(),
      }),
    );
    _throwIfBad(response, 'Failed to save gift category');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upsertGift(Map<String, dynamic> payload) async {
    final giftId = payload['gift_id']?.toString().trim() ?? '';
    if (giftId.isEmpty) throw Exception('Gift ID is required');
    final response = await http.put(
      Uri.parse(VmApiConfig.endpoint('/admin/economy/gifts/items/$giftId')),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _throwIfBad(response, 'Failed to save gift item');
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, String>> _headers() async {
    await authApiService.restoreSavedSession();
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No access token available. Please login again.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfBad(http.Response response, String fallback) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = response.body.trim();
    if (body.isEmpty) throw Exception('$fallback (${response.statusCode})');
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString();
        if (detail != null && detail.trim().isNotEmpty) throw Exception(detail);
      }
    } catch (_) {
      throw Exception(body);
    }
    throw Exception('$fallback (${response.statusCode})');
  }
}
