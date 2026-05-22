import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class InboxAiApiService {
  const InboxAiApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<InboxAiSearchResponse> search(String query) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox-ai/search')),
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{'query': query}),
    );
    _throwIfFailed(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Inbox AI returned an unexpected response.');
    }
    return InboxAiSearchResponse.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<Map<String, String>> _headers() async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Log in to use Inbox AI.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = 'Inbox AI search is unavailable.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }
    } catch (_) {
      // Keep fallback.
    }
    throw Exception(message);
  }
}

class InboxAiSearchResponse {
  const InboxAiSearchResponse({
    required this.query,
    required this.results,
    this.interpretedFilters = const <String, String>{},
  });

  final String query;
  final Map<String, String> interpretedFilters;
  final List<InboxAiSearchResult> results;

  factory InboxAiSearchResponse.fromJson(Map<String, dynamic> json) {
    final filters = json['interpreted_filters'];
    final results = json['results'];
    return InboxAiSearchResponse(
      query: json['query']?.toString() ?? '',
      interpretedFilters: filters is Map
          ? filters.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
      results: results is List
          ? results
                .whereType<Map>()
                .map(
                  (item) => InboxAiSearchResult.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <InboxAiSearchResult>[],
    );
  }
}

class InboxAiSearchResult {
  const InboxAiSearchResult({
    required this.conversationId,
    required this.title,
    required this.snippet,
    required this.matchReason,
    required this.isLocked,
    this.messageId,
    this.time,
  });

  final String conversationId;
  final String? messageId;
  final String title;
  final String snippet;
  final String matchReason;
  final bool isLocked;
  final DateTime? time;

  factory InboxAiSearchResult.fromJson(Map<String, dynamic> json) {
    return InboxAiSearchResult(
      conversationId: json['conversation_id']?.toString() ?? '',
      messageId: json['message_id']?.toString(),
      title: json['title']?.toString() ?? 'Chat',
      snippet: json['snippet']?.toString() ?? '',
      matchReason: json['match_reason']?.toString() ?? 'Matched chat',
      isLocked: json['is_locked'] == true,
      time: DateTime.tryParse(json['time']?.toString() ?? ''),
    );
  }
}
