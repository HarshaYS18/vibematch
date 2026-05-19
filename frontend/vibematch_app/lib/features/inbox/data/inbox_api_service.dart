import 'dart:convert';

import 'package:flutter/material.dart';
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

  Future<InboxLockStatus> loadLockStatus() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/inbox/lock/status')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'load inbox lock status');
    return lockStatusFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String?> startLockSetup({required String mobileNumber}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/lock/setup/start')),
      headers: await _headers(),
      body: jsonEncode({'mobile_number': mobileNumber}),
    );
    _throwIfFailed(response, 'start inbox lock setup');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['debug_otp']?.toString();
  }

  Future<InboxLockStatus> verifyLockSetup({
    required String mobileNumber,
    required String otp,
    required String lockCode,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/lock/setup/verify')),
      headers: await _headers(),
      body: jsonEncode({
        'mobile_number': mobileNumber,
        'otp': otp,
        'lock_code': lockCode,
      }),
    );
    _throwIfFailed(response, 'verify inbox lock setup');
    return lockStatusFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> verifyLock({required String lockCode}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/lock/verify')),
      headers: await _headers(),
      body: jsonEncode({'lock_code': lockCode}),
    );
    _throwIfFailed(response, 'verify inbox lock');
  }

  Future<InboxLockStatus> changeLock({
    required String currentLockCode,
    required String newLockCode,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/lock/change')),
      headers: await _headers(),
      body: jsonEncode({
        'current_lock_code': currentLockCode,
        'new_lock_code': newLockCode,
      }),
    );
    _throwIfFailed(response, 'change inbox lock');
    return lockStatusFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String?> startLockRecovery({required String mobileNumber}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/lock/recovery/start')),
      headers: await _headers(),
      body: jsonEncode({'mobile_number': mobileNumber}),
    );
    _throwIfFailed(response, 'start inbox lock recovery');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['debug_otp']?.toString();
  }

  Future<InboxLockStatus> verifyLockRecovery({
    required String mobileNumber,
    required String otp,
    required String newLockCode,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/lock/recovery/verify')),
      headers: await _headers(),
      body: jsonEncode({
        'mobile_number': mobileNumber,
        'otp': otp,
        'new_lock_code': newLockCode,
      }),
    );
    _throwIfFailed(response, 'recover inbox lock');
    return lockStatusFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> requestCsLockRecovery() async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/lock/recovery/request-cs')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'request CS lock recovery');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['message']?.toString() ?? 'Recovery request submitted.';
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
        .map(conversationFromJson)
        .toList();
  }

  Future<InboxConversation> getConversation(String conversationId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/$conversationId')),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'load conversation');
    return conversationFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<InboxConversation> createDirectConversation({
    required int targetUserId,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/conversations/direct')),
      headers: await _headers(),
      body: jsonEncode({'target_user_id': targetUserId}),
    );
    _throwIfFailed(response, 'create direct conversation');
    return conversationFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<InboxConversation> updateConversationState({
    required String conversationId,
    bool? isMuted,
    bool? isPinned,
    bool? isLocked,
    bool? isBlocked,
  }) async {
    final body = <String, Object>{};
    if (isMuted != null) body['is_muted'] = isMuted;
    if (isPinned != null) body['is_pinned'] = isPinned;
    if (isLocked != null) body['is_locked'] = isLocked;
    if (isBlocked != null) body['is_blocked'] = isBlocked;

    final response = await http.patch(
      Uri.parse(
        VmApiConfig.endpoint('/inbox/conversations/$conversationId/state'),
      ),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _throwIfFailed(response, 'update conversation state');
    return conversationFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<InboxMessage> sendMessage({
    required String conversationId,
    required String text,
    String type = 'text',
    String? replyToText,
    String? inviteRoomName,
    String? inviteRoomId,
    String? attachmentUrl,
  }) async {
    final body = <String, Object>{'text': text, 'type': type};
    if (replyToText != null) body['reply_to_text'] = replyToText;
    if (inviteRoomName != null) body['invite_room_name'] = inviteRoomName;
    if (inviteRoomId != null) body['invite_room_id'] = inviteRoomId;
    if (attachmentUrl != null) body['attachment_url'] = attachmentUrl;

    final response = await http.post(
      Uri.parse(
        VmApiConfig.endpoint('/inbox/conversations/$conversationId/messages'),
      ),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _throwIfFailed(response, 'send message');
    return messageFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxMessage> updateMessage({
    required String conversationId,
    required String messageId,
    String? reaction,
    bool? isStarred,
  }) async {
    final body = <String, Object>{};
    if (reaction != null) body['reaction'] = reaction;
    if (isStarred != null) body['is_starred'] = isStarred;

    final response = await http.patch(
      Uri.parse(
        VmApiConfig.endpoint(
          '/inbox/conversations/$conversationId/messages/$messageId',
        ),
      ),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    _throwIfFailed(response, 'update message');
    return messageFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        VmApiConfig.endpoint(
          '/inbox/conversations/$conversationId/messages/$messageId',
        ),
      ),
      headers: await _headers(),
    );
    _throwIfFailed(response, 'unsend message');
  }

  Future<InboxReportTask> submitReport({
    required InboxConversation conversation,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse(
        VmApiConfig.endpoint('/inbox/conversations/${conversation.id}/reports'),
      ),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    _throwIfFailed(response, 'submit report');
    return reportFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<InboxReportTask>> loadReportTasks() async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/inbox/reports/tasks')),
      headers: await _headers(),
    );
    if (response.statusCode == 403) return const [];
    _throwIfFailed(response, 'load report tasks');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final items = decoded['tasks'] as List<dynamic>? ?? const [];
    return items.whereType<Map<String, dynamic>>().map(reportFromJson).toList();
  }

  Future<InboxReportTask> rejectReport(InboxReportTask task) async =>
      _postReportDecision(task.id, 'reject');
  Future<InboxReportTask> acceptReport(InboxReportTask task) async =>
      _postReportDecision(task.id, 'accept');

  Future<InboxReportTask> applyMonitorAction(
    InboxReportTask task,
    String actionLabel,
  ) async {
    final response = await http.post(
      Uri.parse(
        VmApiConfig.endpoint('/inbox/reports/tasks/${task.id}/monitor-action'),
      ),
      headers: await _headers(),
      body: jsonEncode({'action_label': actionLabel}),
    );
    _throwIfFailed(response, 'apply monitor action');
    return reportFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<InboxReportTask> _postReportDecision(String id, String action) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/inbox/reports/tasks/$id/$action')),
      headers: await _headers(),
      body: jsonEncode({}),
    );
    _throwIfFailed(response, '$action report');
    return reportFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(
      'Inbox API failed to $action (${response.statusCode}): ${response.body}',
    );
  }

  InboxLockStatus lockStatusFromJson(Map<String, dynamic> json) {
    return InboxLockStatus(
      isEnabled: json['is_enabled'] == true,
      mobileNumber: json['mobile_number']?.toString(),
      recoveryRequested: json['recovery_requested'] == true,
    );
  }

  InboxConversation conversationFromJson(Map<String, dynamic> json) {
    final colors =
        (json['colors'] as List<dynamic>? ?? const ['#6D5DF6', '#E84C72'])
            .map((value) => _colorFromHex(value.toString()))
            .toList();
    return InboxConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Chat',
      subtitle: json['subtitle']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      avatarText: json['avatar_text']?.toString() ?? 'VM',
      avatarUrl: _nullableString(json['avatar_url']),
      type: _conversationTypeFromApi(json['type']?.toString()),
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] == true,
      lastSeenText: json['last_seen_text']?.toString() ?? 'offline',
      lastSeenAt: _dateTimeValue(json['last_seen_at']),
      colors: colors,
      messages: (json['messages'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(messageFromJson)
          .toList(),
      currentRoomName: _nullableString(json['current_room_name']),
      currentRoomId: _nullableString(json['current_room_id']),
      isLockedByBackend: json['is_locked_by_backend'] == true,
      isBlocked: json['is_blocked'] == true,
      isMuted: json['is_muted'] == true,
      isPinned: json['is_pinned'] == true,
      isArchived: json['is_archived'] == true,
      chatStreakCount: _intValue(json['chat_streak_count']),
      chatStreakActiveToday: json['chat_streak_active_today'] == true,
    );
  }

  InboxMessage messageFromJson(Map<String, dynamic> json) {
    return InboxMessage(
      id: json['id']?.toString(),
      sender: json['sender']?.toString() ?? 'User',
      text: json['text']?.toString() ?? '',
      time: json['time']?.toString() ?? 'Now',
      isMine: json['is_mine'] == true,
      type: _messageTypeFromApi(json['type']?.toString()),
      status: _messageStatusFromApi(json['status']?.toString()),
      reaction: _nullableString(json['reaction']),
      replyToText: _nullableString(json['reply_to_text']),
      isStarred: json['is_starred'] == true,
      isForwarded: json['is_forwarded'] == true,
      inviteRoomName: _nullableString(json['invite_room_name']),
      inviteRoomId: _nullableString(json['invite_room_id']),
      loveBondRequestId: _nullableString(json['love_bond_request_id']),
      loveBondCardName: _nullableString(json['love_bond_card_name']),
      loveBondStatus: _nullableString(json['love_bond_status']),
      attachmentUrl: _nullableString(json['attachment_url']),
      localAttachmentPath: _nullableString(json['local_attachment_path']),
      mediaExpired: json['media_expired'] == true,
      expiredMediaUrl: _nullableString(json['expired_media_url']),
      localFirstAllowed: json['local_first_allowed'] == true,
      createdAt: _dateTimeValue(json['created_at']),
    );
  }

  InboxReportTask reportFromJson(Map<String, dynamic> json) {
    return InboxReportTask(
      id: json['id']?.toString() ?? '',
      reportedConversationId:
          json['reported_conversation_id']?.toString() ?? '',
      reportedUserName: json['reported_user_name']?.toString() ?? 'User',
      reporterName: json['reporter_name']?.toString() ?? 'Reporter',
      reason: json['reason']?.toString() ?? '',
      snapshot: (json['snapshot'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(messageFromJson)
          .toList(),
      createdAtLabel: json['created_at_label']?.toString() ?? 'Now',
      status: _reportStatusFromApi(json['status']?.toString()),
      csNote: _nullableString(json['cs_note']),
      monitorAction: _nullableString(json['monitor_action']),
    );
  }

  InboxConversationType _conversationTypeFromApi(String? value) {
    switch (value) {
      case 'official':
        return InboxConversationType.official;
      case 'room_invite':
        return InboxConversationType.roomInvite;
      case 'stranger':
        return InboxConversationType.stranger;
      default:
        return InboxConversationType.chat;
    }
  }

  InboxMessageType _messageTypeFromApi(String? value) {
    switch (value) {
      case 'image':
        return InboxMessageType.image;
      case 'voice':
        return InboxMessageType.voice;
      case 'document':
        return InboxMessageType.document;
      case 'location':
        return InboxMessageType.location;
      case 'room_invite':
        return InboxMessageType.roomInvite;
      case 'relationship_request':
        return InboxMessageType.relationshipRequest;
      case 'system':
        return InboxMessageType.system;
      default:
        return InboxMessageType.text;
    }
  }

  InboxMessageStatus _messageStatusFromApi(String? value) {
    switch (value) {
      case 'sent':
        return InboxMessageStatus.sent;
      case 'delivered':
        return InboxMessageStatus.delivered;
      case 'failed':
        return InboxMessageStatus.failed;
      case 'sending':
        return InboxMessageStatus.sending;
      default:
        return InboxMessageStatus.read;
    }
  }

  InboxReportStatus _reportStatusFromApi(String? value) {
    switch (value) {
      case 'rejected_by_cs':
        return InboxReportStatus.rejectedByCs;
      case 'accepted_escalated':
        return InboxReportStatus.acceptedEscalated;
      case 'monitor_action_taken':
        return InboxReportStatus.monitorActionTaken;
      default:
        return InboxReportStatus.pendingCsReview;
    }
  }


  DateTime? _dateTimeValue(Object? value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Color _colorFromHex(String value) {
    var hex = value.replaceAll('#', '').trim();
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.tryParse(hex, radix: 16) ?? 0xFF6D5DF6);
  }

  String? _nullableString(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }
}