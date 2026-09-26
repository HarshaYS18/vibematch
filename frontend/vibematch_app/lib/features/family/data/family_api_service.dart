import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_local_storage.dart';
import '../models/family_ui_models.dart';

class FamilyApiService {
  const FamilyApiService();

  Future<FamilyMeResponse> getMyFamily() async {
    final json = await _getMap('/families/me');
    return FamilyMeResponse.fromJson(json);
  }

  Future<List<FamilyRankUiModel>> getRankings({
    FamilyRankingPeriod period = FamilyRankingPeriod.weekly,
    int limit = 100,
  }) async {
    final json = await _getMap(
      '/families/rankings?period=${period.backendValue}&limit=${limit.clamp(1, 100)}',
    );
    final entries = json['entries'] ?? json['rankings'] ?? json['families'];
    if (entries is! List) return const <FamilyRankUiModel>[];
    return entries
        .whereType<Map>()
        .map((item) => _rankFromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<List<FamilyMemberUiModel>> getMembers({required String familyId}) async {
    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty) return const <FamilyMemberUiModel>[];
    final json = await _getMap('/families/$cleanFamilyId/members');
    final members = json['members'] ?? json['entries'] ?? json['items'];
    if (members is! List) return const <FamilyMemberUiModel>[];
    return members
        .whereType<Map>()
        .map((item) => _memberFromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<FamilyExpConfig> getExpConfig() async {
    final json = await _getMap('/families/config/exp');
    return FamilyExpConfig.fromJson(json);
  }

  Future<FamilyProfileUiModel> createFamily({
    required String name,
    required String minimumVipLabel,
  }) async {
    final json = await _postMap(
      '/families',
      body: <String, dynamic>{
        'name': name.trim(),
        'minimum_vip_label': minimumVipLabel.trim(),
      },
    );
    return _profileFromJson(_map(json['family'] ?? json));
  }

  Future<void> requestJoinFamily({required String familyId}) async {
    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty) return;
    await _postMap('/families/$cleanFamilyId/join-requests', body: const <String, dynamic>{});
  }

  Future<void> leaveFamily({required String familyId}) async {
    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty) return;
    await _postMap('/families/$cleanFamilyId/leave', body: const <String, dynamic>{});
  }

  Future<void> disbandFamily({required String familyId}) async {
    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty) return;
    await _postMap('/families/$cleanFamilyId/disband', body: const <String, dynamic>{});
  }

  Future<void> setAdmins({
    required String familyId,
    required Set<String> adminUserIds,
  }) async {
    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty) return;
    await _postMap(
      '/families/$cleanFamilyId/admins',
      body: <String, dynamic>{'admin_user_ids': adminUserIds.toList(growable: false)},
    );
  }

  Future<List<FamilyChatUiModel>> getChatMessages({
    required String familyId,
  }) async {
    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty) return const <FamilyChatUiModel>[];
    final json = await _getMap('/families/$cleanFamilyId/chat');
    final raw = json['messages'];
    if (raw is! List) return const <FamilyChatUiModel>[];
    return raw
        .whereType<Map>()
        .map((item) => _chatFromJson(item.cast<String, dynamic>()))
        .toList(growable: false);
  }

  Future<FamilyChatUiModel> sendChatMessage({
    required String familyId,
    required String text,
  }) async {
    final cleanFamilyId = familyId.trim();
    final cleanText = text.trim();
    if (cleanFamilyId.isEmpty || cleanText.isEmpty) {
      throw Exception('Family message is empty.');
    }
    final json = await _postMap(
      '/families/$cleanFamilyId/chat/messages',
      body: <String, dynamic>{'text': cleanText},
    );
    return _chatFromJson(_map(json['message']));
  }

  Future<void> sendInvites({
    required String familyId,
    required Set<String> userIds,
  }) async {
    final cleanFamilyId = familyId.trim();
    if (cleanFamilyId.isEmpty || userIds.isEmpty) return;
    await _postMap(
      '/families/$cleanFamilyId/invites',
      body: <String, dynamic>{'user_ids': userIds.toList(growable: false)},
    );
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: await _headers(),
    );
    return _decodeMap(response, 'GET $path');
  }

  Future<Map<String, dynamic>> _postMap(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint(path)),
      headers: <String, String>{
        ...await _headers(),
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _decodeMap(response, 'POST $path');
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthLocalStorage().getAccessToken();
    return <String, String>{
      'Accept': 'application/json',
      if (token != null && token.trim().isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeMap(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('$label failed (${response.statusCode}): ${response.body}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return const <String, dynamic>{};
  }
}

enum FamilyRankingPeriod {
  daily,
  weekly,
  monthly;

  String get backendValue {
    switch (this) {
      case FamilyRankingPeriod.daily:
        return 'daily';
      case FamilyRankingPeriod.weekly:
        return 'weekly';
      case FamilyRankingPeriod.monthly:
        return 'monthly';
    }
  }
}

class FamilyMeResponse {
  const FamilyMeResponse({
    required this.hasFamily,
    required this.isOwner,
    required this.isAdmin,
    required this.profile,
    required this.members,
    required this.rankings,
  });

  final bool hasFamily;
  final bool isOwner;
  final bool isAdmin;
  final FamilyProfileUiModel? profile;
  final List<FamilyMemberUiModel> members;
  final List<FamilyRankUiModel> rankings;

  factory FamilyMeResponse.fromJson(Map<String, dynamic> json) {
    final family = json['family'];
    final members = json['members'];
    final rankings = json['rankings'];
    final profile = family == null ? null : _profileFromJson(_map(family));
    return FamilyMeResponse(
      hasFamily: _bool(json['has_family'], fallback: profile != null),
      isOwner: _bool(json['is_owner'], fallback: false),
      isAdmin: _bool(json['is_admin'], fallback: false),
      profile: profile,
      members: members is List
          ? members
                .whereType<Map>()
                .map((item) => _memberFromJson(item.cast<String, dynamic>()))
                .toList(growable: false)
          : const <FamilyMemberUiModel>[],
      rankings: rankings is List
          ? rankings
                .whereType<Map>()
                .map((item) => _rankFromJson(item.cast<String, dynamic>()))
                .toList(growable: false)
          : const <FamilyRankUiModel>[],
    );
  }
}

class FamilyExpConfig {
  const FamilyExpConfig({required this.raw});

  final Map<String, dynamic> raw;

  factory FamilyExpConfig.fromJson(Map<String, dynamic> json) {
    return FamilyExpConfig(raw: json);
  }
}

FamilyProfileUiModel _profileFromJson(Map<String, dynamic> json) {
  final id = _string(json['id'] ?? json['family_id'] ?? json['public_id'], fallback: 'family');
  final totalExp = _int(json['total_exp'] ?? json['exp'] ?? json['quarter_carry_exp']);
  return FamilyProfileUiModel(
    id: id,
    name: _string(json['name'] ?? json['family_name'], fallback: 'Vibe Family'),
    minimumVipLabel: _string(json['minimum_vip_label'] ?? json['minimum_vip'], fallback: 'VIP 0'),
    memberCount: _int(json['member_count'] ?? json['members_count']),
    maxMembers: _int(json['max_members']) <= 0 ? 200 : _int(json['max_members']),
    rankLabel: _string(json['rank_label'] ?? json['rank'], fallback: 'Unranked'),
    ownerUserId: _string(json['owner_user_id'] ?? json['owner_public_user_id'], fallback: ''),
    quarterCarryExp: totalExp,
    giftCoinsThisQuarter: _int(json['gift_coins_this_quarter'] ?? json['gift_exp']),
    timeMinutesToday: _int(json['time_minutes_today'] ?? json['time_exp_minutes']),
  );
}

FamilyRankUiModel _rankFromJson(Map<String, dynamic> json) {
  final family = _map(json['family']).isEmpty ? json : _map(json['family']);
  final seed = _int(family['id'] ?? family['family_id'] ?? json['rank']);
  final totalExp = _int(json['score'] ?? json['total_exp'] ?? family['total_exp'] ?? family['exp']);
  final rank = _int(json['rank'] ?? family['rank']);
  return FamilyRankUiModel(
    id: _string(family['id'] ?? family['family_id'] ?? family['public_id'], fallback: 'family_$rank'),
    name: _string(family['name'] ?? family['family_name'], fallback: 'Vibe Family'),
    rank: rank <= 0 ? 1 : rank,
    totalExp: totalExp,
    memberCount: _int(family['member_count'] ?? family['members_count']),
    maxMembers: _int(family['max_members']) <= 0 ? 200 : _int(family['max_members']),
    rankLabel: _string(family['rank_label'] ?? json['rank_label'], fallback: '#${rank <= 0 ? 1 : rank}'),
    minimumVipLabel: _string(family['minimum_vip_label'] ?? family['minimum_vip'], fallback: 'VIP 0'),
    ownerUserId: _string(family['owner_user_id'] ?? family['owner_public_user_id'], fallback: ''),
    avatarGradient: _gradient(seed),
  );
}

FamilyMemberUiModel _memberFromJson(Map<String, dynamic> json) {
  final user = _map(json['user']).isEmpty ? json : _map(json['user']);
  final roleText = _string(json['role'] ?? user['family_role'], fallback: 'member').toLowerCase();
  final seed = _int(user['id'] ?? user['public_user_id']);
  return FamilyMemberUiModel(
    userId: _string(user['id'] ?? user['public_user_id'] ?? json['user_id'], fallback: 'user_$seed'),
    name: _string(user['display_name'] ?? user['username'] ?? json['name'], fallback: 'Vibe User'),
    role: roleText.contains('owner')
        ? FamilyRole.owner
        : roleText.contains('admin')
            ? FamilyRole.admin
            : FamilyRole.member,
    contributionExp: _int(json['contribution_exp'] ?? json['exp'] ?? json['score']),
    avatarGradient: _gradient(seed),
    isFollowing: _bool(json['is_following'], fallback: false),
  );
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const <String, dynamic>{};
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _string(Object? value, {required String fallback}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

bool _bool(Object? value, {required bool fallback}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
  }
  return fallback;
}

List<Color> _gradient(int seed) {
  final gradients = <List<Color>>[
    const [Color(0xFF12C7B7), Color(0xFF6D5DF6)],
    const [Color(0xFFFFC857), Color(0xFFE84C72)],
    const [Color(0xFF7C3AED), Color(0xFF22D3EE)],
    const [Color(0xFF34D399), Color(0xFFFFB020)],
  ];
  return gradients[seed.abs() % gradients.length];
}


FamilyChatUiModel _chatFromJson(Map<String, dynamic> json) {
  return FamilyChatUiModel(
    senderName: _string(json['sender'], fallback: 'Family member'),
    message: _string(json['text'], fallback: ''),
    timeLabel: _string(json['time'], fallback: ''),
    isMine: _bool(json['is_mine'], fallback: false),
  );
}
