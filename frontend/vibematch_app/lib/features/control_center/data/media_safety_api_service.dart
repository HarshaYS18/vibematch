import '../../../core/network/api_client.dart';
import '../../auth/data/auth_api_service.dart';

class MediaSafetyApiService {
  MediaSafetyApiService({
    ApiClient? apiClient,
    AuthApiService? authApiService,
  }) : _apiClient = apiClient ?? ApiClient(),
       _authApiService = authApiService ?? const AuthApiService();

  final ApiClient _apiClient;
  final AuthApiService _authApiService;

  Future<MediaSafetyDashboard> loadDashboard() async {
    final json = await _apiClient.getMap(
      '/admin/media-safety/dashboard',
      headers: _headers(),
    );
    return MediaSafetyDashboard.fromJson(json);
  }

  Future<List<CdnMediaAsset>> loadAssets({
    String? mediaType,
    String? moderationStatus,
    String? deletionStatus,
    int limit = 50,
  }) async {
    final json = await _apiClient.getList(
      '/admin/media-safety/assets',
      headers: _headers(),
      queryParameters: {
        'media_type': mediaType,
        'moderation_status': moderationStatus,
        'deletion_status': deletionStatus,
        'limit': '$limit',
      },
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(CdnMediaAsset.fromJson)
        .toList(growable: false);
  }

  Future<List<MediaSafetySetting>> loadSettings() async {
    final json = await _apiClient.getList(
      '/admin/media-safety/settings',
      headers: _headers(),
    );
    return json
        .whereType<Map<String, dynamic>>()
        .map(MediaSafetySetting.fromJson)
        .toList(growable: false);
  }

  Map<String, String> _headers() {
    final token = _authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before opening Media & Safety.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  void close() => _apiClient.close();
}

class MediaSafetyDashboard {
  const MediaSafetyDashboard({
    required this.totalCount,
    required this.pendingReviewCount,
    required this.deletionFailedCount,
    required this.inboxExpiringCount,
    required this.recentAssets,
  });

  final int totalCount;
  final int pendingReviewCount;
  final int deletionFailedCount;
  final int inboxExpiringCount;
  final List<CdnMediaAsset> recentAssets;

  factory MediaSafetyDashboard.fromJson(Map<String, dynamic> json) =>
      MediaSafetyDashboard(
        totalCount: _int(json['total_count']),
        pendingReviewCount: _int(json['pending_review_count']),
        deletionFailedCount: _int(json['deletion_failed_count']),
        inboxExpiringCount: _int(json['inbox_expiring_count']),
        recentAssets: json['recent_assets'] is List
            ? (json['recent_assets'] as List)
                .whereType<Map<String, dynamic>>()
                .map(CdnMediaAsset.fromJson)
                .toList(growable: false)
            : const <CdnMediaAsset>[],
      );
}

class CdnMediaAsset {
  const CdnMediaAsset({
    required this.publicId,
    required this.mediaType,
    required this.objectKey,
    required this.publicUrl,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadStatus,
    required this.moderationStatus,
    required this.deletionStatus,
    required this.createdAt,
    this.ownerUserId,
    this.publicUserId,
    this.linkedEntityType,
    this.linkedEntityId,
    this.moderationSummary,
    this.reviewReason,
    this.expiresAt,
  });

  final String publicId;
  final int? ownerUserId;
  final int? publicUserId;
  final String mediaType;
  final String objectKey;
  final String publicUrl;
  final String mimeType;
  final int sizeBytes;
  final String uploadStatus;
  final String moderationStatus;
  final String deletionStatus;
  final String? linkedEntityType;
  final String? linkedEntityId;
  final String? moderationSummary;
  final String? reviewReason;
  final String? expiresAt;
  final String createdAt;

  String get title => '${mediaType.replaceAll('_', ' ')} • $uploadStatus';
  String get subtitle => 'User ${publicUserId ?? '-'} • ${(sizeBytes / 1024).toStringAsFixed(1)} KB';

  factory CdnMediaAsset.fromJson(Map<String, dynamic> json) => CdnMediaAsset(
        publicId: json['public_id']?.toString() ?? '',
        ownerUserId: json['owner_user_id'] == null ? null : _int(json['owner_user_id']),
        publicUserId: json['public_user_id'] == null ? null : _int(json['public_user_id']),
        mediaType: json['media_type']?.toString() ?? 'media',
        objectKey: json['object_key']?.toString() ?? '',
        publicUrl: json['public_url']?.toString() ?? '',
        mimeType: json['mime_type']?.toString() ?? '',
        sizeBytes: _int(json['size_bytes']),
        uploadStatus: json['upload_status']?.toString() ?? '',
        moderationStatus: json['moderation_status']?.toString() ?? '',
        deletionStatus: json['deletion_status']?.toString() ?? '',
        linkedEntityType: _text(json['linked_entity_type']),
        linkedEntityId: _text(json['linked_entity_id']),
        moderationSummary: _text(json['moderation_summary']),
        reviewReason: _text(json['review_reason']),
        expiresAt: _text(json['expires_at']),
        createdAt: json['created_at']?.toString() ?? '',
      );
}

class MediaSafetySetting {
  const MediaSafetySetting({
    required this.key,
    required this.valueJson,
    required this.description,
    required this.updatedAt,
  });

  final String key;
  final Map<String, dynamic> valueJson;
  final String? description;
  final String updatedAt;

  factory MediaSafetySetting.fromJson(Map<String, dynamic> json) =>
      MediaSafetySetting(
        key: json['key']?.toString() ?? '',
        valueJson: json['value_json'] is Map<String, dynamic>
            ? json['value_json'] as Map<String, dynamic>
            : <String, dynamic>{},
        description: _text(json['description']),
        updatedAt: json['updated_at']?.toString() ?? '',
      );
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return null;
  return text;
}
