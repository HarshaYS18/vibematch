import 'package:flutter/material.dart';

import 'package:vibematch_app/foundation/networking/app_network_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../../rooms/data/room_api_service.dart';
import '../models/search_result_item.dart';
import '../models/search_result_type.dart';

class SearchApiService {
  SearchApiService({AppNetworkClient? apiClient, AuthApiService? authApiService, RoomApiService? roomApiService})
      : _apiClient = apiClient ?? AppNetworkRuntime.shared,
        _authApiService = authApiService ?? const AuthApiService(),
        _roomApiService = roomApiService ?? const RoomApiService();

  final AppNetworkClient _apiClient;
  final AuthApiService _authApiService;
  final RoomApiService _roomApiService;

  Future<List<SearchResultItem>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const <SearchResultItem>[];

    final results = <SearchResultItem>[];
    final userResults = await _searchUsers(clean);
    results.addAll(userResults);

    final roomResults = await _searchRooms(clean);
    results.addAll(roomResults);

    return results;
  }

  Future<List<SearchResultItem>> _searchUsers(String query) async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) return const <SearchResultItem>[];

    final response = await _apiClient.getMap(
      '/users/search',
      queryParameters: {'q': query, 'limit': '20'},
      headers: {'Authorization': 'Bearer $token'},
    );
    final rawUsers = response['users'];
    if (rawUsers is! List) return const <SearchResultItem>[];

    return rawUsers.whereType<Map<String, dynamic>>().map(_userToResult).toList(growable: false);
  }

  Future<List<SearchResultItem>> _searchRooms(String query) async {
    final rooms = await _roomApiService.listTrendingRooms(limit: 50);
    final clean = query.toLowerCase();
    return rooms.where((room) {
      return room.id.toLowerCase().contains(clean) ||
          room.name.toLowerCase().contains(clean) ||
          room.language.toLowerCase().contains(clean) ||
          room.mode.toLowerCase().contains(clean) ||
          room.type.toLowerCase().contains(clean);
    }).map(_roomToResult).toList(growable: false);
  }

  SearchResultItem _userToResult(Map<String, dynamic> json) {
    final publicUserId = json['public_user_id']?.toString() ?? '';
    final displayName = _text(json['display_name']) ?? _text(json['username']) ?? (publicUserId.isEmpty ? 'Vibe User' : 'User $publicUserId');
    final username = _text(json['username']);
    final primaryRole = _text(json['primary_role']) ?? 'user';
    final isFriend = json['is_friend'] == true;
    final isFollowing = json['is_following'] == true;
    final followsMe = json['follows_me'] == true;
    final vip = json['vip'] is Map<String, dynamic> ? json['vip'] as Map<String, dynamic> : <String, dynamic>{};
    final vipLevel = _int(vip['vip_level']);
    final subtitleParts = <String>[
      if (username != null) '@$username',
      'ID $publicUserId',
      if (vipLevel > 0) 'VIP $vipLevel',
      if (isFriend) 'Friend' else if (isFollowing) 'Following' else if (followsMe) 'Follows you',
    ];

    return SearchResultItem(
      type: SearchResultType.user,
      title: displayName,
      subtitle: subtitleParts.join(' · '),
      tag: _roleLabel(primaryRole),
      icon: Icons.person_rounded,
      color: _userColor(primaryRole),
      keywords: [displayName, username ?? '', publicUserId, primaryRole],
      userId: publicUserId,
      username: username,
    );
  }

  SearchResultItem _roomToResult(RealRoom room) {
    return SearchResultItem(
      type: SearchResultType.room,
      title: room.name,
      subtitle: '${room.onlineCount} online · ${room.language} · ${room.mode}',
      tag: room.type,
      icon: Icons.graphic_eq_rounded,
      color: const Color(0xFF12C7B7),
      keywords: [room.name, room.id, room.language, room.mode, room.type],
      roomId: room.id,
      roomLanguage: room.language,
      roomModeTitle: room.mode,
      roomOnlineCount: room.onlineCount,
    );
  }

  void close() {
    _apiClient.close();
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _roleLabel(String role) {
  final normalized = role.toLowerCase();
  if (normalized.contains('founder') || normalized == 'owner') return 'Official';
  if (normalized.contains('admin')) return 'Admin';
  if (normalized.contains('monitor')) return 'Monitor';
  if (normalized.contains('cs')) return 'CS';
  return 'User';
}

Color _userColor(String role) {
  final normalized = role.toLowerCase();
  if (normalized.contains('founder') || normalized == 'owner') return const Color(0xFFFFC857);
  if (normalized.contains('admin')) return const Color(0xFF8C5CF6);
  if (normalized.contains('monitor')) return const Color(0xFFE84C72);
  return const Color(0xFF12C7B7);
}
