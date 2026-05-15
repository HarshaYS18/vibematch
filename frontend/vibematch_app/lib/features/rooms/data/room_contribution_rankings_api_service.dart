import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';
import '../presentation/live_room_models.dart';
import '../presentation/widgets/rankings/room_rankings_models.dart';

class RoomContributionRankingsApiService {
  const RoomContributionRankingsApiService();

  Future<List<RoomRankingEntry>> fetchRoomContributions({
    required String roomPublicId,
    required RoomRankingPeriod period,
  }) async {
    final cleanRoomId = roomPublicId.trim();
    if (cleanRoomId.isEmpty || cleanRoomId == 'unknown_room') return const <RoomRankingEntry>[];

    final token = await AuthLocalStorage().getAccessToken();
    final headers = <String, String>{'Accept': 'application/json'};
    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http.get(
      Uri.parse(
        VmApiConfig.endpoint(
          '/rooms/$cleanRoomId/rankings/contribution?period=${period.backendValue}&category=sent&limit=100',
        ),
      ),
      headers: headers,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load room contributions (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return const <RoomRankingEntry>[];
    final entries = decoded['entries'];
    if (entries is! List) return const <RoomRankingEntry>[];

    return entries
        .whereType<Map>()
        .map((item) => _entryFromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  RoomRankingEntry _entryFromJson(Map<String, dynamic> json) {
    final userJson = _map(json['user']);
    final user = SeatUser(
      id: '${_int(userJson['public_user_id']) == 0 ? _int(userJson['id']) : _int(userJson['public_user_id'])}',
      name: _string(userJson['display_name'], fallback: _string(userJson['username'], fallback: 'Vibe User')),
      roleLabel: 'member',
      familyName: '',
      relationshipText: '',
      vipLevel: _int(userJson['vip_level']),
      svipLevel: _int(userJson['svip_level']),
      sendingLevel: _int(userJson['sending_level']),
      receivingLevel: _int(userJson['receiving_level']),
      sentExp: _int(userJson['monthly_sent']),
      receivedExp: _int(userJson['monthly_received']),
      medals: const <String>[],
      avatarColors: _avatarColors(_int(userJson['id'])),
      avatarUrl: _nullableString(userJson['avatar_url']),
    );

    return RoomRankingEntry(
      rank: _int(json['rank']),
      user: user,
      score: _int(json['score']),
      scoreText: _string(json['score_text'], fallback: compactNumber(_int(json['score']))),
      scoreLabel: _string(json['score_label'], fallback: 'coin'),
      subtitle: _string(json['subtitle'], fallback: 'Sent Lv ${user.sendingLevel}'),
    );
  }
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _string(dynamic value, {required String fallback}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<Color> _avatarColors(int seed) {
  final colors = <List<Color>>[
    const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    const [Color(0xFFFF5F7E), Color(0xFFFFC857)],
    const [Color(0xFF6D5DF6), Color(0xFFE84C72)],
    const [Color(0xFF4A9BFF), Color(0xFF12C7B7)],
  ];
  return colors[seed.abs() % colors.length];
}
