import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

class ApiClient {
  ApiClient();

  String get baseUrl {
    // For Chrome/web local development.
    return AppConstants.webApiBaseUrl;

    // Later for Android emulator, use:
    // return AppConstants.apiBaseUrl;
  }

  Future<Map<String, dynamic>> getHealthStatus() async {
    final uri = Uri.parse('$baseUrl/api/health/');

    final response = await http.get(uri).timeout(
          const Duration(seconds: 8),
        );

    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}