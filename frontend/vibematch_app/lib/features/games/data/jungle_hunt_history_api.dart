import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class JungleHuntHistoryApi {
  const JungleHuntHistoryApi({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<List<JungleHuntHistoryItem>> loadHistory({int limit = 30}) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before playing games.');
    }

    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/games/global/jungle-hunt/history?limit=$limit')),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load Jungle Hunt history (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['items'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(JungleHuntHistoryItem.fromJson)
        .toList(growable: false);
  }
}

class JungleHuntHistoryItem {
  const JungleHuntHistoryItem({
    required this.roundId,
    required this.winningTargetId,
    required this.label,
    required this.emoji,
    required this.multiplier,
    required this.completedAt,
  });

  final int roundId;
  final int winningTargetId;
  final String label;
  final String? emoji;
  final int multiplier;
  final String? completedAt;

  factory JungleHuntHistoryItem.fromJson(Map<String, dynamic> json) {
    return JungleHuntHistoryItem(
      roundId: _int(json['round_id']),
      winningTargetId: _int(json['winning_target_id']),
      label: json['label']?.toString() ?? 'Target',
      emoji: _text(json['emoji']),
      multiplier: _int(json['multiplier']),
      completedAt: _text(json['completed_at']),
    );
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
