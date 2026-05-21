import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../presentation/help_center/help_center_store.dart';

class SupportApiService {
  const SupportApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<List<HelpCenterTicket>> loadTickets() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/support/tickets')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'load support tickets');
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <HelpCenterTicket>[];
    return decoded
        .whereType<Map>()
        .map(
          (item) =>
              HelpCenterTicket.fromRemote(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<HelpCenterTicket> createTicket({
    required String category,
    required String subject,
    required String message,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/support/tickets')),
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{
        'category': _backendCategory(category),
        'subject': subject,
        'message': message,
        'attachments': const <Map<String, dynamic>>[],
      }),
    );
    _throwIfFailed(response, 'create support ticket');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Support returned an unexpected response.');
    }
    return HelpCenterTicket.fromRemote(Map<String, dynamic>.from(decoded));
  }

  Future<SupportAssistantReply> ask(String message) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/support/ask')),
      headers: await _headers(),
      body: jsonEncode(<String, dynamic>{'message': message}),
    );
    _throwIfFailed(response, 'ask support assistant');
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Support assistant returned an unexpected response.');
    }
    return SupportAssistantReply.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<Map<String, String>> _headers() async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Log in to use support.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var detail = 'Could not $action.';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        detail = decoded['detail'].toString();
      }
    } catch (_) {
      // Keep the friendly fallback.
    }
    throw Exception(detail);
  }

  String _backendCategory(String value) {
    switch (value.toLowerCase()) {
      case 'payments':
        return 'recharge_issue';
      case 'safety':
        return 'report_user';
      case 'rooms':
        return 'room_issue';
      case 'inbox':
        return 'inbox_issue';
      case 'vip':
        return 'vip_svip_issue';
      case 'account':
        return 'account_issue';
      default:
        return 'other';
    }
  }
}

class SupportAssistantReply {
  const SupportAssistantReply({
    required this.suggestedReply,
    required this.category,
    required this.priority,
    required this.missingFields,
    required this.shouldCreateTicket,
    required this.shouldEscalate,
    required this.provider,
    required this.articles,
  });

  final String suggestedReply;
  final String category;
  final String priority;
  final List<String> missingFields;
  final bool shouldCreateTicket;
  final bool shouldEscalate;
  final String provider;
  final List<SupportArticlePreview> articles;

  factory SupportAssistantReply.fromJson(Map<String, dynamic> json) {
    final classification = Map<String, dynamic>.from(
      json['classification'] as Map? ?? const <String, dynamic>{},
    );
    final rawArticles = json['matching_articles'];
    return SupportAssistantReply(
      suggestedReply:
          classification['suggested_reply']?.toString() ??
          'Vibe Match Team · AI Assistant: I can help create a support ticket.',
      category: classification['category']?.toString() ?? 'other',
      priority: classification['priority']?.toString() ?? 'normal',
      missingFields:
          (classification['missing_fields'] as List? ?? const <Object?>[])
              .map((item) => item.toString())
              .toList(),
      shouldCreateTicket: classification['should_create_ticket'] == true,
      shouldEscalate: classification['should_escalate'] == true,
      provider: classification['provider']?.toString() ?? 'local_rules',
      articles: rawArticles is List
          ? rawArticles
                .whereType<Map>()
                .map(
                  (item) => SupportArticlePreview.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <SupportArticlePreview>[],
    );
  }
}

class SupportArticlePreview {
  const SupportArticlePreview({
    required this.title,
    required this.body,
    required this.category,
  });

  final String title;
  final String body;
  final String category;

  factory SupportArticlePreview.fromJson(Map<String, dynamic> json) {
    return SupportArticlePreview(
      title: json['title']?.toString() ?? 'Help article',
      body: json['body']?.toString() ?? '',
      category: json['category']?.toString() ?? 'General',
    );
  }
}
