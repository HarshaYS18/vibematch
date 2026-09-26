import 'package:flutter/material.dart';

import 'package:vibematch_app/foundation/networking/app_network_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/search_result_item.dart';
import '../models/search_result_type.dart';

/// Canonical Search/OpenSearch client.
///
/// Search is a rebuildable projection. The existing UI remains unchanged and
/// routes stable identifiers from typed search results rather than parsing text.
class SearchApiService {
  SearchApiService({
    AppNetworkClient? apiClient,
    AuthApiService? authApiService,
  })  : _apiClient = apiClient ?? AppNetworkRuntime.shared,
        _authApiService = authApiService ?? const AuthApiService();

  final AppNetworkClient _apiClient;
  final AuthApiService _authApiService;

  Future<List<SearchResultItem>> search(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const <SearchResultItem>[];

    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      return const <SearchResultItem>[];
    }

    final response = await _apiClient.getMap(
      '/search',
      queryParameters: {'q': clean, 'limit': '30'},
      headers: {'Authorization': 'Bearer $token'},
    );
    final rawResults = response['results'];
    if (rawResults is! List) return const <SearchResultItem>[];

    return rawResults
        .whereType<Map<String, dynamic>>()
        .map(_toResult)
        .whereType<SearchResultItem>()
        .toList(growable: false);
  }

  SearchResultItem? _toResult(Map<String, dynamic> json) {
    final kind = _text(json['kind']);
    final id = _text(json['public_id']);
    final title = _text(json['title']);
    if (kind == null || id == null || title == null) return null;

    final subtitle = _text(json['subtitle']) ?? '';
    final tags = (json['tags'] is List)
        ? (json['tags'] as List)
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
        : const <String>[];

    switch (kind) {
      case 'user':
        return SearchResultItem(
          type: SearchResultType.user,
          title: title,
          subtitle: subtitle,
          tag: tags.isEmpty ? 'User' : tags.first,
          icon: Icons.person_rounded,
          color: const Color(0xFF12C7B7),
          keywords: <String>[title, subtitle, id, ...tags],
          userId: id,
        );
      case 'room':
        return SearchResultItem(
          type: SearchResultType.room,
          title: title,
          subtitle: subtitle,
          tag: tags.isEmpty ? 'Room' : tags.first,
          icon: Icons.graphic_eq_rounded,
          color: const Color(0xFF12C7B7),
          keywords: <String>[title, subtitle, id, ...tags],
          roomId: id,
          roomLanguage: _text(json['language']),
        );
      case 'vibe':
        return SearchResultItem(
          type: SearchResultType.vibe,
          title: title,
          subtitle: subtitle,
          tag: tags.isEmpty ? 'Vibe' : tags.first,
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF8C5CF6),
          keywords: <String>[title, subtitle, id, ...tags],
          vibeId: id,
        );
      default:
        return null;
    }
  }

  void close() {
    _apiClient.close();
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty || text == 'null' ? null : text;
}
