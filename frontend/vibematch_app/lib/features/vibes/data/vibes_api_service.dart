import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/vibe_models.dart';

class VibesApiService {
  const VibesApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<List<VibeItem>> loadFeed({
    int limit = 30,
    VibesFeedTab tab = VibesFeedTab.vibes,
  }) async {
    final path = tab == VibesFeedTab.friends ? '/vibes/friends' : '/vibes/feed';
    final response = await http.get(
      Uri.parse(
        VmApiConfig.endpoint(path),
      ).replace(queryParameters: {'limit': '$limit'}),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load Vibes feed');
    return _postsFromResponse(response.body);
  }

  Future<List<VibeItem>> loadSavedVibes({int limit = 50}) async {
    final response = await http.get(
      Uri.parse(
        VmApiConfig.endpoint('/vibes/saved'),
      ).replace(queryParameters: {'limit': '$limit'}),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load saved Vibes');
    return _postsFromResponse(response.body);
  }

  Future<VibeItem> getVibe(String postId) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load Vibe detail');
    return _vibeFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<VibeItem> createVibe(VibeItem vibe) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/vibes')),
      headers: _authHeaders(contentType: true),
      body: jsonEncode({
        'caption': vibe.caption,
        'media_type': _mediaTypeToApi(vibe.mediaType),
        'media_url': vibe.mediaUrl,
        'tag': vibe.tag,
        'mentions': vibe.mentions,
        'uses_mention_all': vibe.usesMentionAll,
        'comments_enabled': vibe.commentsEnabled,
      }),
    );
    _throwIfFailed(response, 'create Vibe');
    return _vibeFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<VibeLikeResult> toggleLike(String postId) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/like')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'toggle Vibe like');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return VibeLikeResult(
      postId: decoded['post_id']?.toString() ?? postId,
      likedByMe: decoded['liked_by_me'] == true,
      likesCount: _int(decoded['likes_count']),
    );
  }

  Future<VibeSaveResult> toggleSave(String postId) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/save')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'toggle Vibe save');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return VibeSaveResult(
      postId: decoded['post_id']?.toString() ?? postId,
      savedByMe: decoded['saved_by_me'] == true,
      savesCount: _int(decoded['saves_count']),
    );
  }

  Future<VibeShareResult> shareVibe(
    String postId, {
    int? targetPublicUserId,
    String shareChannel = 'inbox',
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/share')),
      headers: _authHeaders(contentType: true),
      body: jsonEncode({
        'target_public_user_id': targetPublicUserId,
        'share_channel': shareChannel,
      }),
    );
    _throwIfFailed(response, 'share Vibe');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return VibeShareResult(
      postId: decoded['post_id']?.toString() ?? postId,
      sharesCount: _int(decoded['shares_count']),
      shareChannel: decoded['share_channel']?.toString() ?? shareChannel,
      targetPublicUserId: _nullableInt(decoded['target_public_user_id']),
    );
  }

  Future<VibeReportResult> reportVibe(
    String postId, {
    required String reason,
    String? details,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/report')),
      headers: _authHeaders(contentType: true),
      body: jsonEncode({'reason': reason, 'details': details}),
    );
    _throwIfFailed(response, 'report Vibe');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return VibeReportResult(
      postId: decoded['post_id']?.toString() ?? postId,
      reportId: _int(decoded['id']),
      reason: decoded['reason']?.toString() ?? reason,
      status: decoded['status']?.toString() ?? 'PENDING',
    );
  }

  Future<List<VibeReportQueueItem>> loadReportQueue({
    String status = 'PENDING',
    int limit = 50,
  }) async {
    final response = await http.get(
      Uri.parse(
        VmApiConfig.endpoint('/admin/moderation/vibes/reports'),
      ).replace(queryParameters: {'status': status, 'limit': '$limit'}),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load Vibe report queue');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final reports = decoded['reports'] as List<dynamic>? ?? const [];
    return reports
        .whereType<Map<String, dynamic>>()
        .map(VibeReportQueueItem.fromJson)
        .toList(growable: false);
  }

  Future<VibeReportResult> reviewReport(
    int reportId, {
    required String status,
    bool deletePost = false,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/admin/moderation/vibes/reports/$reportId/review')),
      headers: _authHeaders(contentType: true),
      body: jsonEncode({'status': status, 'delete_post': deletePost}),
    );
    _throwIfFailed(response, 'review Vibe report');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return VibeReportResult(
      postId: decoded['post_id']?.toString() ?? '',
      reportId: _int(decoded['id']),
      reason: decoded['reason']?.toString() ?? '',
      status: decoded['status']?.toString() ?? status,
    );
  }

  Future<List<VibeComment>> loadComments(
    String postId, {
    int limit = 100,
  }) async {
    final response = await http.get(
      Uri.parse(
        VmApiConfig.endpoint('/vibes/$postId/comments'),
      ).replace(queryParameters: {'limit': '$limit'}),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load Vibe comments');
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(_commentFromJson)
        .toList(growable: false);
  }

  Future<VibeComment> addComment(
    String postId,
    String text, {
    String? parentCommentId,
  }) async {
    final parentId = parentCommentId == null || parentCommentId.trim().isEmpty
        ? null
        : int.tryParse(parentCommentId);
    final payload = <String, dynamic>{'text': text.trim()};
    if (parentId != null) payload['parent_comment_id'] = parentId;
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/comments')),
      headers: _authHeaders(contentType: true),
      body: jsonEncode(payload),
    );
    _throwIfFailed(response, 'add Vibe comment');
    return _commentFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<VibeCommentLikeResult> toggleCommentLike(
    String postId,
    String commentId,
  ) async {
    final response = await http.post(
      Uri.parse(
        VmApiConfig.endpoint('/vibes/$postId/comments/$commentId/like'),
      ),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'toggle comment like');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return VibeCommentLikeResult(
      commentId: decoded['comment_id']?.toString() ?? commentId,
      likedByMe: decoded['liked_by_me'] == true,
      likesCount: _int(decoded['likes_count']),
    );
  }

  Future<bool> toggleCommentPin(String postId, String commentId) async {
    final response = await http.patch(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/comments/$commentId/pin')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'pin Vibe comment');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return decoded['is_pinned'] == true;
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final response = await http.delete(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/comments/$commentId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'delete Vibe comment');
  }

  Future<void> deleteVibe(String postId) async {
    final response = await http.delete(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId')),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'delete Vibe');
  }

  Map<String, String> _authHeaders({bool contentType = false}) {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty)
      throw Exception('Please login again before using Vibes.');
    return {
      if (contentType) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception(
      'Failed to $action (${response.statusCode}): ${response.body}',
    );
  }
}

class VibeLikeResult {
  const VibeLikeResult({
    required this.postId,
    required this.likedByMe,
    required this.likesCount,
  });
  final String postId;
  final bool likedByMe;
  final int likesCount;
}

class VibeCommentLikeResult {
  const VibeCommentLikeResult({
    required this.commentId,
    required this.likedByMe,
    required this.likesCount,
  });
  final String commentId;
  final bool likedByMe;
  final int likesCount;
}

class VibeSaveResult {
  const VibeSaveResult({
    required this.postId,
    required this.savedByMe,
    required this.savesCount,
  });
  final String postId;
  final bool savedByMe;
  final int savesCount;
}

class VibeShareResult {
  const VibeShareResult({
    required this.postId,
    required this.sharesCount,
    required this.shareChannel,
    required this.targetPublicUserId,
  });
  final String postId;
  final int sharesCount;
  final String shareChannel;
  final int? targetPublicUserId;
}

class VibeReportResult {
  const VibeReportResult({
    required this.postId,
    required this.reportId,
    required this.reason,
    required this.status,
  });
  final String postId;
  final int reportId;
  final String reason;
  final String status;
}

class VibeReportQueueItem {
  const VibeReportQueueItem({
    required this.id,
    required this.postId,
    required this.reporterName,
    required this.postAuthorName,
    required this.postCaption,
    required this.postMediaType,
    required this.reason,
    required this.status,
    required this.createdAtText,
  });
  final int id;
  final int postId;
  final String reporterName;
  final String postAuthorName;
  final String postCaption;
  final String postMediaType;
  final String reason;
  final String status;
  final String createdAtText;

  factory VibeReportQueueItem.fromJson(Map<String, dynamic> json) {
    final reporter = json['reporter'] is Map<String, dynamic>
        ? json['reporter'] as Map<String, dynamic>
        : <String, dynamic>{};
    final author = json['post_author'] is Map<String, dynamic>
        ? json['post_author'] as Map<String, dynamic>
        : <String, dynamic>{};
    return VibeReportQueueItem(
      id: _int(json['id']),
      postId: _int(json['post_id']),
      reporterName:
          _text(reporter['display_name']) ??
          _text(reporter['username']) ??
          'Reporter',
      postAuthorName:
          _text(author['display_name']) ??
          _text(author['username']) ??
          'Vibe User',
      postCaption: json['post_caption']?.toString() ?? '',
      postMediaType: json['post_media_type']?.toString() ?? 'text',
      reason: json['reason']?.toString() ?? 'Report',
      status: json['status']?.toString() ?? 'PENDING',
      createdAtText: _timeAgo(json['created_at']?.toString()),
    );
  }
}

List<VibeItem> _postsFromResponse(String body) {
  final decoded = jsonDecode(body) as Map<String, dynamic>;
  final posts = decoded['posts'] as List<dynamic>? ?? const [];
  return posts
      .whereType<Map<String, dynamic>>()
      .map(_vibeFromJson)
      .toList(growable: false);
}

VibeItem _vibeFromJson(Map<String, dynamic> json) {
  final author = json['author'] is Map<String, dynamic>
      ? json['author'] as Map<String, dynamic>
      : <String, dynamic>{};
  final displayName =
      _text(author['display_name']) ?? _text(author['username']) ?? 'Vibe User';
  final authorPublicId =
      author['public_user_id']?.toString() ?? author['id']?.toString() ?? '';
  final mediaType = _mediaTypeFromApi(json['media_type']?.toString());
  final mentionsRaw = json['mentions'];
  final mediaUrl = _text(json['media_url']);
  return VibeItem(
    id: json['id']?.toString() ?? '',
    authorName: displayName,
    authorId: authorPublicId,
    avatarText: displayName.trim().isEmpty
        ? 'V'
        : displayName.trim()[0].toUpperCase(),
    timeAgo: _timeAgo(json['created_at']?.toString()),
    mediaType: mediaType,
    caption: json['caption']?.toString() ?? '',
    tag: json['tag']?.toString() ?? mediaType.label,
    likes: _int(json['likes_count']),
    comments: _int(json['comments_count']),
    shares: _int(json['shares_count']),
    saves: _int(json['saves_count']),
    views: _int(json['views_count']),
    isFollowing: true,
    usesMentionAll: json['uses_mention_all'] == true,
    commentsEnabled: json['comments_enabled'] != false,
    mentions: mentionsRaw is List
        ? mentionsRaw.map((item) => item.toString()).toList(growable: false)
        : const <String>[],
    colors: mediaType.colors,
    mediaUrl: mediaUrl == null ? null : VmApiConfig.mediaUrl(mediaUrl),
    avatarUrl: _text(author['avatar_url']),
    likedByMe: json['liked_by_me'] == true,
    savedByMe: json['saved_by_me'] == true,
  );
}

VibeComment _commentFromJson(Map<String, dynamic> json) {
  final author = json['author'] is Map<String, dynamic>
      ? json['author'] as Map<String, dynamic>
      : <String, dynamic>{};
  final displayName =
      _text(author['display_name']) ?? _text(author['username']) ?? 'Vibe User';
  return VibeComment(
    id: json['id']?.toString() ?? '',
    parentCommentId: _text(json['parent_comment_id']),
    name: displayName,
    avatarText: displayName.trim().isEmpty
        ? 'V'
        : displayName.trim()[0].toUpperCase(),
    text: json['text']?.toString() ?? '',
    time: _timeAgo(json['created_at']?.toString()),
    avatarUrl: _text(author['avatar_url']),
    isPinned: json['is_pinned'] == true,
    canPin: json['can_pin'] == true,
    canDelete: json['can_delete'] == true,
    likedByMe: json['liked_by_me'] == true,
    likesCount: _int(json['likes_count']),
  );
}

String _mediaTypeToApi(VibeMediaType type) => switch (type) {
  VibeMediaType.photo => 'photo',
  VibeMediaType.video => 'video',
  VibeMediaType.text => 'text',
};
VibeMediaType _mediaTypeFromApi(String? value) =>
    switch (value?.toLowerCase()) {
      'video' => VibeMediaType.video,
      'text' => VibeMediaType.text,
      _ => VibeMediaType.photo,
    };

String _timeAgo(String? raw) {
  final created = _parseBackendUtcTimestamp(raw);
  if (created == null) return 'Just now';
  final diff = DateTime.now().difference(created);
  if (diff.isNegative) return 'Just now';
  if (diff.inSeconds < 10) return 'Just now';
  if (diff.inSeconds < 60) return 'few seconds ago';
  if (diff.inMinutes == 1) return '1 min ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours == 1) return '1h ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return '1d ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

DateTime? _parseBackendUtcTimestamp(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
  return DateTime.tryParse(hasTimezone ? value : '${value}Z')?.toLocal();
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
