import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../constants/app_constants.dart';
import 'image_picker_service.dart';

class MediaUploadResponse {
  const MediaUploadResponse({
    required this.storageBackend,
    required this.storageKey,
    required this.publicUrl,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.sizeMb,
    required this.bucket,
    required this.moderationStatus,
  });

  factory MediaUploadResponse.fromJson(Map<String, dynamic> json) {
    return MediaUploadResponse(
      storageBackend: json['storage_backend']?.toString() ?? 'local',
      storageKey: json['storage_key']?.toString() ?? '',
      publicUrl: json['public_url']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      contentType: json['content_type']?.toString() ?? '',
      sizeBytes: json['size_bytes'] is int ? json['size_bytes'] as int : 0,
      sizeMb: json['size_mb'] is num ? (json['size_mb'] as num).toDouble() : 0,
      bucket: json['bucket']?.toString() ?? '',
      moderationStatus: json['moderation_status']?.toString() ?? '',
    );
  }

  final String storageBackend;
  final String storageKey;
  final String publicUrl;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final double sizeMb;
  final String bucket;
  final String moderationStatus;
}

class MediaUploadResult {
  const MediaUploadResult._({this.media, this.errorMessage});

  factory MediaUploadResult.success(MediaUploadResponse media) {
    return MediaUploadResult._(media: media);
  }

  factory MediaUploadResult.failure(String errorMessage) {
    return MediaUploadResult._(errorMessage: errorMessage);
  }

  final MediaUploadResponse? media;
  final String? errorMessage;

  bool get hasMedia => media != null;
  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;
}

class MediaUploadService {
  const MediaUploadService({String? baseUrl})
      : _baseUrl = baseUrl ?? AppConstants.apiBaseUrl;

  final String _baseUrl;

  Future<MediaUploadResult> uploadChatImage(PickedVibeImage image) {
    return _uploadFile(
      image: image,
      endpointPath: '/media-api/upload/chat-image',
    );
  }

  Future<MediaUploadResult> uploadRoomImage(PickedVibeImage image) {
    return _uploadFile(
      image: image,
      endpointPath: '/media-api/upload/room-image',
    );
  }

  Future<MediaUploadResult> uploadAvatar(PickedVibeImage image) {
    return _uploadFile(
      image: image,
      endpointPath: '/media-api/upload/avatar',
    );
  }

  Future<MediaUploadResult> _uploadFile({
    required PickedVibeImage image,
    required String endpointPath,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _buildUri(endpointPath));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.file.path,
          filename: image.displayName,
          contentType: _contentTypeForExtension(image.extension),
        ),
      );

      final streamedResponse = await request.send().timeout(AppConstants.receiveTimeout);
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode < 200 || streamedResponse.statusCode >= 300) {
        return MediaUploadResult.failure(_extractErrorMessage(responseBody));
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        return MediaUploadResult.failure('Upload response was invalid.');
      }

      final media = MediaUploadResponse.fromJson(decoded);
      return MediaUploadResult.success(
        MediaUploadResponse(
          storageBackend: media.storageBackend,
          storageKey: media.storageKey,
          publicUrl: _absolutePublicUrl(media.publicUrl),
          filename: media.filename,
          contentType: media.contentType,
          sizeBytes: media.sizeBytes,
          sizeMb: media.sizeMb,
          bucket: media.bucket,
          moderationStatus: media.moderationStatus,
        ),
      );
    } catch (error) {
      return MediaUploadResult.failure('Image upload failed. Check backend/CDN connection.');
    }
  }

  Uri _buildUri(String endpointPath) {
    final base = Uri.parse(_baseUrl);
    return base.replace(path: endpointPath);
  }

  MediaType _contentTypeForExtension(String extension) {
    final clean = extension.toLowerCase().replaceAll('.', '').trim();
    return switch (clean) {
      'jpg' || 'jpeg' => MediaType('image', 'jpeg'),
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'gif' => MediaType('image', 'gif'),
      'heic' => MediaType('image', 'heic'),
      'heif' => MediaType('image', 'heif'),
      'apng' => MediaType('image', 'apng'),
      _ => MediaType('image', 'jpeg'),
    };
  }

  String _absolutePublicUrl(String publicUrl) {
    if (publicUrl.startsWith('http://') || publicUrl.startsWith('https://')) {
      return publicUrl;
    }

    final base = Uri.parse(_baseUrl);
    final cleanPath = publicUrl.startsWith('/') ? publicUrl : '/$publicUrl';
    return base.replace(path: cleanPath, query: '').toString();
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail != null) return detail.toString();
      }
    } catch (_) {
      // Keep fallback below.
    }
    return 'Image upload failed.';
  }
}
