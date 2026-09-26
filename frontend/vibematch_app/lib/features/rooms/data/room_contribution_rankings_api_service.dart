import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

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
    final vipJson = _map(userJson['vip']);
    final vipSummaryJson = _map(userJson['vip_summary']);
    final publicUserId = _firstInt([
      userJson['public_user_id'],
      userJson['publicUserId'],
      userJson['id'],
      json['public_user_id'],
    ]);
    final internalUserId = _firstInt([userJson['id'], userJson['user_id'], publicUserId]);
    final vipLevel = _firstInt([
      userJson['vip_level'],
      userJson['vipLevel'],
      userJson['vip'],
      vipJson['vip_level'],
      vipJson['level'],
      vipSummaryJson['vip_level'],
      vipSummaryJson['level'],
      json['vip_level'],
    ]);
    final svipLevel = _firstInt([
      userJson['svip_level'],
      userJson['svipLevel'],
      vipJson['svip_level'],
      vipSummaryJson['svip_level'],
      json['svip_level'],
    ]);
    final sendingLevel = _firstInt([
      userJson['sending_level'],
      userJson['send_level'],
      userJson['sendLevel'],
      json['sending_level'],
      json['send_level'],
    ]);
    final receivingLevel = _firstInt([
      userJson['receiving_level'],
      userJson['receive_level'],
      userJson['receiveLevel'],
      json['receiving_level'],
      json['receive_level'],
    ]);

    final user = SeatUser(
      id: 'user_$publicUserId',
      name: _string(userJson['display_name'], fallback: _string(userJson['username'], fallback: 'Vibe User')),
      roleLabel: 'member',
      familyName: '',
      relationshipText: '',
      vipLevel: vipLevel,
      svipLevel: svipLevel,
      sendingLevel: sendingLevel,
      receivingLevel: receivingLevel,
      sentExp: _firstInt([userJson['monthly_sent'], userJson['sent_exp'], json['score']]),
      receivedExp: _firstInt([userJson['monthly_received'], userJson['received_exp']]),
      medals: const <String>[],
      avatarColors: _avatarColors(internalUserId),
      avatarUrl: _nullableString(userJson['avatar_url']),
    );

    return RoomRankingEntry(
      rank: _int(json['rank']),
      user: user,
      score: _int(json['score']),
      scoreText: _string(json['score_text'] ?? json['score_display'], fallback: compactNumber(_int(json['score']))),
      scoreLabel: _string(json['score_label'], fallback: 'coin'),
      subtitle: '',
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

int _firstInt(List<dynamic> values) {
  for (final value in values) {
    final parsed = _int(value);
    if (parsed != 0) return parsed;
  }
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