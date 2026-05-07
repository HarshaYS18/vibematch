import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/inbox_models.dart';

class InboxApiService {
  InboxApiService({AuthApiService authApiService = const AuthApiService()})
      : _authApiService = authApiService;

  final AuthApiService _authApiService;

  Future<Map<String, String>> _headers() async {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('No auth token available for Inbox API. Login first.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<InboxConversation>> loadConversations() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'load conversations');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['conversations'] as List<dynamic>? ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(_conversationFromJson)
        .toList();
  }

  Future<InboxConversation> updateConversationState({
    required String conversationId,
    bool? isMuted,
    bool? isPinned,
    bool? isLocked,
    bool? isBlocked,
  }) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/$conversationId/state')),
      headers: await _headers(),
      body: jsonEncode({
        if (isMuted != null) 'is_muted': isMuted,
        if (isPinned != null) 'is_pinned': isPinned,
        if (isLocked != null) 'is_locked': isLocked,
        if (isBlocked != null) 'is_blocked': isBlocked,
      }),
    );
    _throwIfFailed(response, 'update conversation state');
    return _conversationFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxMessage> sendMessage({
    required String conversationId,
    required String text,
    String type = 'text',
    String? replyToText,
    String? inviteRoomName,
    String? attachmentUrl,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/$conversationId/messages')),
      headers: await _headers(),
      body: jsonEncode({
        'text': text,
        'type': type,
        if (replyToText != null) 'reply_to_text': replyToText,
        if (inviteRoomName != null) 'invite_room_name': inviteRoomName,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      }),
    );
    _throwIfFailed(response, 'send message');
    return _messageFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxMessage> updateMessage({
    required String conversationId,
    required String messageId,
    String? reaction,
    bool? isStarred,
  }) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/$conversationId/messages/$messageId')),
      headers: await _headers(),
      body: jsonEncode({
        if (reaction != null) 'reaction': reaction,
        if (isStarred != null) 'is_starred': isStarred,
      }),
    );
    _throwIfFailed(response, 'update message');
    return _messageFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteMessage({required String conversationId, required String messageId}) async {
    final response = await http.delete(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/$conversationId/messages/$messageId')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'delete message');
  }

  Future<InboxReportTask> submitReport({required InboxConversation conversation, required String reason}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/${conversation.id}/reports')),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    _throwIfFailed(response, 'submit report');
    return _reportFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<InboxReportTask>> loadReportTasks() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/inbox/reports/tasks')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'load report tasks');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['tasks'] as List<dynamic>? ?? const [];
    return items.whereType<Map<String, dynamic>>().map(_reportFromJson).toList();
  }

  Future<InboxReportTask> rejectReport(InboxReportTask task) async => _postReportDecision(task.id, 'reject');
  Future<InboxReportTask> acceptReport(InboxReportTask task) async => _postReportDecision(task.id, 'accept');

  Future<InboxReportTask> applyMonitorAction(InboxReportTask task, String actionLabel) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/reports/tasks/${task.id}/monitor-action')),
      headers: await _headers(),
      body: jsonEncode({'action_label': actionLabel}),
    );
    _throwIfFailed(response, 'apply monitor action');
    return _reportFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxReportTask> _postReportDecision(String id, String action) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/reports/tasks/$id/$action')),
      headers: await _headers(),
      body: jsonEncode({}),
    );
    _throwIfFailed(response, '$action report');
    return _reportFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Inbox API failed to $action (${response.statusCode}): ${response.body}');
  }

  InboxConversation _conversationFromJson(Map<String, dynamic> json) {
    final colors = (json['colors'] as List<dynamic>? ?? const ['#6D5DF6', '#E84C72'])
        .map((value) => _colorFromHex(value.toString()))
        .toList();
    return InboxConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Chat',
      subtitle: json['subtitle']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      avatarText: json['avatar_text']?.toString() ?? 'VM',
      type: _conversationTypeFromApi(json['type']?.toString()),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] == true,
      lastSeenText: json['last_seen_text']?.toString() ?? 'offline',
      colors: colors,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_messageFromJson)
          .toList(),
      currentRoomName: json['current_room_name']?.toString(),
      isLockedByBackend: json['is_locked_by_backend'] == true,
      isBlocked: json['is_blocked'] == true,
      isMuted: json['is_muted'] == true,
      isPinned: json['is_pinned'] == true,
      isArchived: json['is_archived'] == true,
    );
  }

  InboxMessage _messageFromJson(Map<String, dynamic> json) {
    return InboxMessage(
      id: json['id']?.toString(),
      sender: json['sender']?.toString() ?? 'User',
      text: json['text']?.toString() ?? '',
      time: json['time']?.toString() ?? 'Now',
      isMine: json['is_mine'] == true,
      type: _messageTypeFromApi(json['type']?.toString()),
      status: _messageStatusFromApi(json['status']?.toString()),
      reaction: json['reaction']?.toString(),
      replyToText: json['reply_to_text']?.toString(),
      isStarred: json['is_starred'] == true,
      isForwarded: json['is_forwarded'] == true,
      inviteRoomName: json['invite_room_name']?.toString(),
    );
  }

  InboxReportTask _reportFromJson(Map<String, dynamic> json) {
    return InboxReportTask(
      id: json['id']?.toString() ?? '',
      reportedConversationId: json['reported_conversation_id']?.toString() ?? '',
      reportedUserName: json['reported_user_name']?.toString() ?? 'User',
      reporterName: json['reporter_name']?.toString() ?? 'Reporter',
      reason: json['reason']?.toString() ?? '',
      snapshot: (json['snapshot'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(_messageFromJson)
          .toList(),
      createdAtLabel: json['created_at_label']?.toString() ?? 'Now',
      status: _reportStatusFromApi(json['status']?.toString()),
      csNote: json['cs_note']?.toString(),
      monitorAction: json['monitor_action']?.toString(),
    );
  }

  InboxConversationType _conversationTypeFromApi(String? value) {
    switch (value) {
      case 'official': return InboxConversationType.official;
      case 'room_invite': return InboxConversationType.roomInvite;
      case 'stranger': return InboxConversationType.stranger;
      default: return InboxConversationType.chat;
    }
  }

  InboxMessageType _messageTypeFromApi(String? value) {
    switch (value) {
      case 'image': return InboxMessageType.image;
      case 'voice': return InboxMessageType.voice;
      case 'document': return InboxMessageType.document;
      case 'location': return InboxMessageType.location;
      case 'room_invite': return InboxMessageType.roomInvite;
      case 'system': return InboxMessageType.system;
      default: return InboxMessageType.text;
    }
  }

  InboxMessageStatus _messageStatusFromApi(String? value) {
    switch (value) {
      case 'sent': return InboxMessageStatus.sent;
      case 'delivered': return InboxMessageStatus.delivered;
      case 'failed': return InboxMessageStatus.failed;
      default: return InboxMessageStatus.read;
    }
  }

  InboxReportStatus _reportStatusFromApi(String? value) {
    switch (value) {
      case 'rejected_by_cs': return InboxReportStatus.rejectedByCs;
      case 'accepted_escalated': return InboxReportStatus.acceptedEscalated;
      case 'monitor_action_taken': return InboxReportStatus.monitorActionTaken;
      default: return InboxReportStatus.pendingCsReview;
    }
  }

  Color _colorFromHex(String value) {
    var hex = value.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF6D5DF6);
  }
}
