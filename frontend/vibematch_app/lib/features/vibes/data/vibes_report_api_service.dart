import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class VibesReportApiService {
  const VibesReportApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<List<VibeReportQueueItem>> loadReports({String status = 'PENDING', int limit = 50}) async {
    final response = await http.get(
      Uri.parse(VmApiConfig.endpoint('/admin/moderation/vibes/reports')).replace(queryParameters: {'status': status, 'limit': '$limit'}),
      headers: _headers(),
    );
    _throwIfFailed(response, 'load Vibes report queue');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final reports = decoded['reports'] as List<dynamic>? ?? const [];
    return reports.whereType<Map<String, dynamic>>().map(VibeReportQueueItem.fromJson).toList(growable: false);
  }

  Future<VibeReportReviewResult> reviewReport({
    required int reportId,
    required String status,
    required bool deletePost,
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse(VmApiConfig.endpoint('/admin/moderation/vibes/reports/$reportId/review')),
      headers: _headers(contentType: true),
      body: jsonEncode({
        'status': status,
        'delete_post': deletePost,
        'note': note,
      }),
    );
    _throwIfFailed(response, 'review Vibes report');
    return VibeReportReviewResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Map<String, String> _headers({bool contentType = false}) {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before reviewing Vibes reports.');
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

class VibeReportQueueItem {
  const VibeReportQueueItem({
    required this.id,
    required this.postId,
    required this.reporter,
    required this.postAuthor,
    required this.postCaption,
    required this.postMediaType,
    required this.reason,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int postId;
  final VibeReportUser reporter;
  final VibeReportUser postAuthor;
  final String postCaption;
  final String postMediaType;
  final String reason;
  final String? details;
  final String status;
  final DateTime createdAt;

  factory VibeReportQueueItem.fromJson(Map<String, dynamic> json) => VibeReportQueueItem(
        id: _int(json['id']),
        postId: _int(json['post_id']),
        reporter: VibeReportUser.fromJson(_map(json['reporter'])),
        postAuthor: VibeReportUser.fromJson(_map(json['post_author'])),
        postCaption: json['post_caption']?.toString() ?? '',
        postMediaType: json['post_media_type']?.toString() ?? 'text',
        reason: json['reason']?.toString() ?? 'Report',
        details: _text(json['details']),
        status: json['status']?.toString() ?? 'PENDING',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class VibeReportUser {
  const VibeReportUser({required this.id, required this.publicUserId, required this.username, required this.displayName, required this.avatarUrl});

  final int id;
  final int publicUserId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get visibleName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return 'User $publicUserId';
  }

  factory VibeReportUser.fromJson(Map<String, dynamic> json) => VibeReportUser(
        id: _int(json['id']),
        publicUserId: _int(json['public_user_id']),
        username: _text(json['username']),
        displayName: _text(json['display_name']),
        avatarUrl: _text(json['avatar_url']),
      );
}

class VibeReportReviewResult {
  const VibeReportReviewResult({required this.id, required this.postId, required this.reason, required this.status});

  final int id;
  final int postId;
  final String reason;
  final String status;

  factory VibeReportReviewResult.fromJson(Map<String, dynamic> json) => VibeReportReviewResult(
        id: _int(json['id']),
        postId: _int(json['post_id']),
        reason: json['reason']?.toString() ?? '',
        status: json['status']?.toString() ?? 'PENDING',
      );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
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
