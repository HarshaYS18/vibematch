import 'dart:convert';

import 'package:vibematch_app/foundation/networking/feature_http_compat.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../data/inbox_api_service.dart';
import '../models/inbox_models.dart';

class InboxMessageToolsApiService {
  InboxMessageToolsApiService({
    AuthApiService? authApiService,
    InboxApiService? inboxApiService,
  })  : _authApiService = authApiService ?? AuthApiService(),
        _inboxApiService = inboxApiService ?? InboxApiService();

  final AuthApiService _authApiService;
  final InboxApiService _inboxApiService;

  Future<Map<String, String>> _headers() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No auth token available for Inbox message tools. Login first.');
    }
    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<InboxMessage> editTextMessage({
    required String conversationId,
    required String messageId,
    required String text,
  }) async {
    final response = await http.patch(
      Uri.parse(
        VmApiConfig.endpoint('/inbox/conversations/$conversationId/messages/$messageId/edit'),
      ),
      headers: await _headers(),
      body: jsonEncode(<String, Object>{'text': text.trim()}),
    );
    _throwIfFailed(response, 'edit message');
    return _inboxApiService.messageFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteForMe({
    required String conversationId,
    required String messageId,
  }) async {
    final response = await http.post(
      Uri.parse(
        VmApiConfig.endpoint('/inbox/conversations/$conversationId/messages/$messageId/delete-for-me'),
      ),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'delete message for me');
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Inbox message tools failed to $action (${response.statusCode}): ${response.body}');
  }
}
