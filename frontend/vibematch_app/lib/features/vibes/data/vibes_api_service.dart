import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../models/vibe_models.dart';

class VibesApiService {
  const VibesApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<List<VibeItem>> loadFeed({int limit = 30}) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/vibes/feed')).replace(queryParameters: {'limit': '$limit'}),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load Vibes feed');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final posts = decoded['posts'] as List<dynamic>? ?? const [];
    return posts.whereType<Map<String, dynamic>>().map(_vibeFromJson).toList(growable: false);
  }

  Future<VibeItem> getVibe(String postId) async {
    final response = await http.get(Uri.parse(VmApiConfig.endpoint('/vibes/$postId')), headers: _authHeaders());
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
      }),
    );
    _throwIfFailed(response, 'create Vibe');
    return _vibeFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<VibeLikeResult> toggleLike(String postId) async {
    final response = await http.post(Uri.parse(VmApiConfig.endpoint('/vibes/$postId/like')), headers: _authHeaders());
    _throwIfFailed(response, 'toggle Vibe like');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return VibeLikeResult(
      postId: decoded['post_id']?.toString() ?? postId,
      likedByMe: decoded['liked_by_me'] == true,
      likesCount: _int(decoded['likes_count']),
    );
  }

  Future<VibeShareResult> shareVibe(String postId, {int? targetPublicUserId, String shareChannel = 'inbox'}) async {
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

  Future<VibeReportResult> reportVibe(String postId, {required String reason, String? details}) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/report')),
      headers: _authHeaders(contentType: true),
      body: jsonEncode({
        'reason': reason,
        'details': details,
      }),
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

  Future<List<VibeComment>> loadComments(String postId, {int limit = 50}) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/comments')).replace(queryParameters: {'limit': '$limit'}),
      headers: _authHeaders(),
    );
    _throwIfFailed(response, 'load Vibe comments');
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.whereType<Map<String, dynamic>>().map(_commentFromJson).toList(growable: false);
  }

  Future<VibeComment> addComment(String postId, String text) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/vibes/$postId/comments')),
      headers: _authHeaders(contentType: true),
      body: jsonEncode({'text': text.trim()}),
    );
    _throwIfFailed(response, 'add Vibe comment');
    return _commentFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteVibe(String postId) async {
    final response = await http.delete(Uri.parse(VmApiConfig.endpoint('/vibes/$postId')), headers: _authHeaders());
    _throwIfFailed(response, 'delete Vibe');
  }

  Map<String, String> _authHeaders({bool contentType = false}) {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before using Vibes.');
    }
    return {
      if (contentType) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  void _throwIfFailed(http.Response response, String action) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw Exception('Failed to $action (${response.statusCode}): ${response.body}');
  }
}

class VibeLikeResult {
  const VibeLikeResult({required this.postId, required this.likedByMe, required this.likesCount});

  final String postId;
  final bool likedByMe;
  final int likesCount;
}

class VibeShareResult {
  const VibeShareResult({required this.postId, required this.sharesCount, required this.shareChannel, required this.targetPublicUserId});

  final String postId;
  final int sharesCount;
  final String shareChannel;
  final int? targetPublicUserId;
}

class VibeReportResult {
  const VibeReportResult({required this.postId, required this.reportId, required this.reason, required this.status});

  final String postId;
  final int reportId;
  final String reason;
  final String status;
}

VibeItem _vibeFromJson(Map<String, dynamic> json) {
  final author = json['author'] is Map<String, dynamic> ? json['author'] as Map<String, dynamic> : <String, dynamic>{};
  final displayName = _text(author['display_name']) ?? _text(author['username']) ?? 'Vibe User';
  final authorPublicId = author['public_user_id']?.toString() ?? author['id']?.toString() ?? '';
  final mediaType = _mediaTypeFromApi(json['media_type']?.toString());
  final mentionsRaw = json['mentions'];
  return VibeItem(
    id: json['id']?.toString() ?? '',
    authorName: displayName,
    authorId: authorPublicId,
    avatarText: displayName.trim().isEmpty ? 'V' : displayName.trim()[0].toUpperCase(),
    timeAgo: _timeAgo(json['created_at']?.toString()),
    mediaType: mediaType,
    caption: json['caption']?.toString() ?? '',
    tag: json['tag']?.toString() ?? mediaType.label,
    likes: _int(json['likes_count']),
    comments: _int(json['comments_count']),
    shares: _int(json['shares_count']),
    views: _int(json['views_count']),
    isFollowing: true,
    usesMentionAll: json['uses_mention_all'] == true,
    mentions: mentionsRaw is List ? mentionsRaw.map((item) => item.toString()).toList(growable: false) : const <String>[],
    colors: mediaType.colors,
    mediaUrl: _text(json['media_url']),
    likedByMe: json['liked_by_me'] == true,
  );
}

VibeComment _commentFromJson(Map<String, dynamic> json) {
  final author = json['author'] is Map<String, dynamic> ? json['author'] as Map<String, dynamic> : <String, dynamic>{};
  final displayName = _text(author['display_name']) ?? _text(author['username']) ?? 'Vibe User';
  return VibeComment(
    name: displayName,
    avatarText: displayName.trim().isEmpty ? 'V' : displayName.trim()[0].toUpperCase(),
    text: json['text']?.toString() ?? '',
    time: _timeAgo(json['created_at']?.toString()),
  );
}

String _mediaTypeToApi(VibeMediaType type) {
  return switch (type) {
    VibeMediaType.photo => 'photo',
    VibeMediaType.video => 'video',
    VibeMediaType.text => 'text',
  };
}

VibeMediaType _mediaTypeFromApi(String? value) {
  return switch (value?.toLowerCase()) {
    'video' => VibeMediaType.video,
    'text' => VibeMediaType.text,
    _ => VibeMediaType.photo,
  };
}

String _timeAgo(String? raw) {
  final created = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  if (created == null) return 'Just now';
  final diff = DateTime.now().difference(created);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${(diff.inDays / 7).floor()}w ago';
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
