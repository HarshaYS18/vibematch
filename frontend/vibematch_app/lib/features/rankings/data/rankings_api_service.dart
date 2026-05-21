import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../models/ranking_models.dart';

class RankingsApiService {
  const RankingsApiService();

  Future<RankingPayload> getRankings({
    required String type,
    required String period,
    int limit = 100,
  }) async {
    final safeType = _safeType(type);
    final safePeriod = _safePeriod(period);
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/rankings/$safeType?period=$safePeriod&limit=$limit')),
      headers: const {'Content-Type': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Backend rankings failed ${response.statusCode}: ${response.body}');
    }
    return RankingPayload.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  String _safeType(String value) {
    const allowed = {'sent', 'received', 'recharge'};
    return allowed.contains(value) ? value : 'sent';
  }

  String _safePeriod(String value) {
    const allowed = {'hourly', 'today', 'weekly', 'monthly'};
    return allowed.contains(value) ? value : 'today';
  }
}
