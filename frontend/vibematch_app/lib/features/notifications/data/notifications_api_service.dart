import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/notification_item.dart';
import '../models/notification_type.dart';

class NotificationsApiService {
  NotificationsApiService({ApiClient? apiClient, AuthApiService? authApiService})
      : _apiClient = apiClient ?? ApiClient(),
        _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Future<NotificationsLoadResult> loadNotifications({int limit = 50, bool unreadOnly = false}) async {
    final response = await _apiClient.getMap(
      '/notifications',
      queryParameters: {
        'limit': '$limit',
        'unread_only': '$unreadOnly',
      },
      headers: _headers(),
    );

    final rawItems = response['notifications'];
    final List<NotificationItem> items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().map(_notificationItemFromBackendJson).toList(growable: false)
        : const <NotificationItem>[];

    return NotificationsLoadResult(
      unreadCount: _int(response['unread_count']),
      items: items,
    );
  }

  Future<void> markRead(String notificationId) async {
    final id = int.tryParse(notificationId);
    if (id == null) return;
    await _apiClient.postMap('/notifications/$id/read', headers: _headers());
  }

  Future<void> markAllRead() async {
    await _apiClient.postMap('/notifications/read-all', headers: _headers());
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before loading notifications.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}

class NotificationsLoadResult {
  const NotificationsLoadResult({required this.unreadCount, required this.items});

  final int unreadCount;
  final List<NotificationItem> items;
}

NotificationItem _notificationItemFromBackendJson(Map<String, dynamic> json) {
  final type = _typeFromBackend(json['type']?.toString());
  final metadata = json['metadata'] is Map<String, dynamic> ? json['metadata'] as Map<String, dynamic> : <String, dynamic>{};
  final authorName = metadata['author_name']?.toString() ?? 'Someone';
  final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
  final body = json['body']?.toString() ?? '';
  return NotificationItem(
    id: json['id']?.toString() ?? '',
    type: type,
    senderName: authorName,
    targetName: '',
    title: json['title']?.toString() ?? 'Notification',
    body: body,
    vibeTitle: _targetTitle(type, body, json['target_id']?.toString()),
    timeAgo: _timeAgo(createdAt),
    isUnread: json['is_read'] != true,
    targetType: json['target_type']?.toString(),
    targetId: json['target_id']?.toString(),
  );
}

NotificationType _typeFromBackend(String? raw) {
  switch (raw) {
    case 'vibe_mention_all':
      return NotificationType.allVibeMention;
    case 'comment_mention':
      return NotificationType.targetedCommentMention;
    case 'vibe_mention':
    default:
      return NotificationType.targetedVibeMention;
  }
}

String _targetTitle(NotificationType type, String body, String? targetId) {
  final label = type == NotificationType.targetedCommentMention ? 'Comment' : 'Vibe';
  final idText = targetId == null || targetId.isEmpty ? '' : ' #$targetId';
  if (body.trim().isEmpty) return '$label$idText';
  return body.trim();
}

String _timeAgo(DateTime? createdAt) {
  if (createdAt == null) return 'now';
  final diff = DateTime.now().difference(createdAt.toLocal());
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
