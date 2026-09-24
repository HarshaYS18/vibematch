import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/store_models.dart';

class StoreApiService {
  const StoreApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<StoreCatalog> fetchCatalog() async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/store/catalog')), headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to load store'));
    }
    return StoreCatalog.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<StoreItem> purchase(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final pendingKey = 'store_purchase_pending_$itemId';
    var purchaseId = prefs.getString(pendingKey);
    if (purchaseId == null || purchaseId.trim().isEmpty) {
      purchaseId = const Uuid().v4();
      await prefs.setString(pendingKey, purchaseId);
    }

    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/store/purchase')),
      headers: _authHeaders(),
      body: jsonEncode({'item_id': itemId, 'purchase_id': purchaseId}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      await prefs.remove(pendingKey);
      return StoreItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    // Definite client rejection means Economy did not accept an uncertain
    // transport outcome; a future user action may start a fresh purchase.
    if (response.statusCode >= 400 && response.statusCode < 500) {
      await prefs.remove(pendingKey);
    }
    throw Exception(_errorMessage(response, fallback: 'Failed to purchase item'));
  }

  Future<UserInventory> fetchInventory() async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/store/inventory')), headers: _authHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to load inventory'));
    }
    return UserInventory.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InventoryItem> equip({required String itemId, bool equipped = true}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/store/inventory/equip')),
      headers: _authHeaders(),
      body: jsonEncode({'item_id': itemId, 'equipped': equipped}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to update inventory item'));
    }
    return InventoryItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _authHeaders() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again.');
    }
    return {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
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
