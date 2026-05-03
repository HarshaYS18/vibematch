import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../auth/data/auth_local_storage.dart';
import '../models/global_search_user_result.dart';

class GlobalSearchApiService {
  GlobalSearchApiService({
    AuthLocalStorage? localStorage,
    http.Client? client,
  })  : _localStorage = localStorage ?? AuthLocalStorage(),
        _client = client ?? http.Client();

  final AuthLocalStorage _localStorage;
  final http.Client _client;

  Future<List<GlobalSearchUserResult>> searchUsers(String query) async {
    final safeQuery = query.trim();
    if (safeQuery.isEmpty) return const <GlobalSearchUserResult>[];

    final token = await _localStorage.getAccessToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Login required before searching users.');
    }

    final uri = Uri.parse('${AppConstants.apiBaseUrl}/users/search').replace(
      queryParameters: <String, String>{
        'q': safeQuery,
        'limit': '30',
      },
    );

    final response = await _client.get(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Search failed (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <GlobalSearchUserResult>[];

    return decoded
        .whereType<Map>()
        .map((item) => GlobalSearchUserResult.fromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }
}
