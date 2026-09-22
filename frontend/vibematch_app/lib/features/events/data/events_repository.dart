import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/event_item.dart';

class EventsRepository {
  EventsRepository({ApiClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? ApiClient(),
        _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;
  CommunityEventsData? _cache;
  DateTime? _cacheAt;

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken?.trim();
    if (token == null || token.isEmpty) throw Exception('Please login again.');
    return <String, String>{'Authorization': 'Bearer $token'};
  }

  Future<CommunityEventsData> fetch({bool force = false}) async {
    final cache = _cache;
    final at = _cacheAt;
    if (!force && cache != null && at != null &&
        DateTime.now().difference(at) < const Duration(seconds: 20)) {
      return cache;
    }
    final json = await _apiClient.getMap(
      '/experience/community-events',
      headers: _headers(),
    );
    final data = _fromJson(json);
    _cache = data;
    _cacheAt = DateTime.now();
    return data;
  }

  Future<void> claimMission(String missionId) async {
    final clean = missionId.trim();
    if (clean.isEmpty) return;
    await _apiClient.postMap(
      '/experience/social-missions/$clean/claim',
      headers: _headers(),
    );
    _cache = null;
    _cacheAt = null;
  }

  CommunityEventsData _fromJson(Map<String, dynamic> json) {
    final events = (json['events'] is List ? json['events'] as List : const [])
        .whereType<Map>()
        .map((raw) => _event(raw.cast<String, dynamic>()))
        .toList(growable: false);
    final missions = (json['missions'] is List ? json['missions'] as List : const [])
        .whereType<Map>()
        .map((raw) => _mission(raw.cast<String, dynamic>()))
        .toList(growable: false);
    return CommunityEventsData(events: events, missions: missions);
  }

  EventItem _event(Map<String, dynamic> json) {
    final kind = (json['kind']?.toString() ?? 'community').trim();
    final visual = _visual(kind);
    return EventItem(
      id: json['id']?.toString() ?? kind,
      kind: kind,
      title: json['title']?.toString() ?? 'Community event',
      subtitle: json['subtitle']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Live',
      rewardText: json['reward_text']?.toString() ?? '',
      startsAt: _utcDate(json['starts_at']) ?? DateTime.now().toUtc(),
      endsAt: _utcDate(json['ends_at']) ?? DateTime.now().toUtc().add(const Duration(days: 1)),
      fallbackIcon: visual.$1,
      gradient: visual.$2,
      imageUrl: _text(json['image_url']),
    );
  }

  SocialMissionItem _mission(Map<String, dynamic> json) {
    final reward = json['reward'] is Map
        ? (json['reward'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return SocialMissionItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Social mission',
      description: json['description']?.toString() ?? '',
      progress: _int(json['progress']),
      requiredCount: _int(json['required']),
      rewardCoins: _int(reward['amount']),
      completed: json['completed'] == true,
      claimed: json['claimed'] == true,
      claimable: json['claimable'] == true,
    );
  }

  (IconData, List<Color>) _visual(String kind) {
    switch (kind) {
      case 'missions':
        return (Icons.verified_rounded, const <Color>[Color(0xFF12C7B7), Color(0xFF6D5DF6)]);
      case 'rooms':
        return (Icons.groups_rounded, const <Color>[Color(0xFFE84C72), Color(0xFF8C5CF6)]);
      case 'family':
        return (Icons.diversity_3_rounded, const <Color>[Color(0xFFC99A3B), Color(0xFFE84C72)]);
      default:
        return (Icons.celebration_rounded, const <Color>[Color(0xFF12C7B7), Color(0xFF8C5CF6)]);
    }
  }

  DateTime? _utcDate(Object? value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(
      raw.endsWith('Z') || raw.contains('+') ? raw : '${raw}Z',
    );
    return parsed?.toUtc();
  }

  int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  void close() => _apiClient.close();
}
