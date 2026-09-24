import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class ChatModerationApiService {
  const ChatModerationApiService({
    this.authApiService = const AuthApiService(),
  });

  final AuthApiService authApiService;

  Future<ChatModerationResult> checkText({
    required String text,
    required String roomId,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/ai-moderation/text')),
      headers: _headers(),
      body: jsonEncode(<String, dynamic>{
        'text': text,
        'surface': 'room_chat',
        'room_id': roomId,
      }),
    );
    _throwIfFailed(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception('Moderation returned an unexpected response.');
    }
    return ChatModerationResult.fromJson(Map<String, dynamic>.from(decoded));
  }

  Map<String, String> _headers() {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Log in to send room messages.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfFailed(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var message = 'Message safety check failed.';
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

class ChatModerationResult {
  const ChatModerationResult({
    required this.decision,
    required this.userMessage,
    required this.categories,
  });

  final String decision;
  final String userMessage;
  final List<String> categories;

  bool get allowed => decision == 'allow';

  factory ChatModerationResult.fromJson(Map<String, dynamic> json) {
    return ChatModerationResult(
      decision: json['decision']?.toString() ?? 'block',
      userMessage:
          json['user_message']?.toString() ??
          'Message blocked by safety checks.',
      categories: (json['categories'] as List? ?? const <Object?>[])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
