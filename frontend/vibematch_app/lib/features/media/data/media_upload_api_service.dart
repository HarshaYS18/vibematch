import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../../../foundation/networking/app_network_client.dart';
import '../../../foundation/networking/direct_upload_transport.dart';
import '../../auth/data/auth_api_service.dart';

class MediaUploadApiService {
  const MediaUploadApiService({
    this.authApiService = const AuthApiService(),
  });

  final AuthApiService authApiService;

  Future<MediaUploadResult> uploadAvatar(File file) {
    return uploadXFile(purpose: 'avatar', file: XFile(file.path));
  }

  Future<MediaUploadResult> uploadRoomAvatar(File file) {
    return uploadXFile(purpose: 'room_avatar', file: XFile(file.path));
  }

  Future<MediaUploadResult> uploadVibeMedia(File file) {
    return uploadXFile(purpose: 'vibes', file: XFile(file.path));
  }

  Future<MediaUploadResult> uploadStoryMediaXFile(XFile file) {
    return uploadXFile(purpose: 'story', file: file);
  }

  Future<MediaUploadResult> uploadChatImage(File file) {
    return uploadXFile(purpose: 'chat_image', file: XFile(file.path));
  }

  Future<MediaUploadResult> uploadChatDocument(File file) {
    return uploadXFile(purpose: 'chat_document', file: XFile(file.path));
  }

  Future<MediaUploadResult> uploadChatVoice(File file) {
    return uploadXFile(purpose: 'chat_voice', file: XFile(file.path));
  }

  Future<MediaUploadResult> uploadVibeMediaXFile(XFile file) {
    return uploadXFile(purpose: 'vibes', file: file);
  }

  Future<MediaUploadResult> uploadChatImageXFile(XFile file) {
    return uploadXFile(purpose: 'chat_image', file: file);
  }

  Future<MediaUploadResult> uploadChatDocumentXFile(XFile file) {
    return uploadXFile(purpose: 'chat_document', file: file);
  }

  Future<MediaUploadResult> uploadChatVoiceXFile(XFile file) {
    return uploadXFile(purpose: 'chat_voice', file: file);
  }

  Future<MediaUploadResult> uploadChatDocumentBytes({
    required List<int> bytes,
    required String filename,
  }) {
    return uploadBytes(
      purpose: 'chat_document',
      bytes: bytes,
      filename: filename,
    );
  }

  Future<MediaUploadResult> uploadChatVoiceBytes({
    required List<int> bytes,
    required String filename,
  }) {
    return uploadBytes(
      purpose: 'chat_voice',
      bytes: bytes,
      filename: filename,
    );
  }

  Future<MediaUploadResult> uploadXFile({
    required String purpose,
    required XFile file,
    String? filename,
  }) async {
    final size = await file.length();
    if (size <= 0) throw Exception('Selected media is empty.');

    final safeName = _safeFilename(filename ?? file.name);
    final source = StreamingUploadSource(
      length: size,
      openRange: (start, endExclusive) => file.openRead(start, endExclusive),
    );
    return _uploadSource(
      purpose: purpose,
      source: source,
      filename: safeName,
      contentType: _contentType(safeName, declared: file.mimeType),
    );
  }

  Future<MediaUploadResult> uploadBytes({
    required String purpose,
    required List<int> bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) throw Exception('Selected media is empty.');

    final safeName = _safeFilename(filename);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final source = StreamingUploadSource(
      length: data.length,
      openRange: (start, endExclusive) => Stream<List<int>>.value(
        Uint8List.sublistView(data, start, endExclusive),
      ),
    );
    return _uploadSource(
      purpose: purpose,
      source: source,
      filename: safeName,
      contentType: _contentType(safeName),
    );
  }

  Future<MediaUploadResult> _uploadSource({
    required String purpose,
    required StreamingUploadSource source,
    required String filename,
    required String contentType,
  }) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before uploading media.');
    }

    final authHeaders = <String, String>{
      'Authorization': 'Bearer $token',
    };
    final network = ApiClientNetworkAdapter();
    final uploadTransport = DirectUploadTransport();

    try {
      final created = await network.postMap(
        '/media/upload-sessions',
        headers: authHeaders,
        body: <String, Object>{
          'purpose': purpose,
          'filename': filename,
          'content_type': contentType,
          'size_bytes': source.length,
        },
      );
      final plan = MediaUploadPlan.fromJson(created);
      if (plan.sessionId.isEmpty ||
          plan.mediaId.isEmpty ||
          plan.uploadMode.isEmpty) {
        throw Exception('Media server returned an invalid upload session.');
      }

      final receipts = <Map<String, Object>>[];
      if (plan.uploadMode == 'multipart') {
        final partSize = plan.partSizeBytes;
        if (partSize == null || partSize <= 0 || plan.parts.isEmpty) {
          throw Exception('Media server returned an invalid multipart plan.');
        }
        for (final part in plan.parts) {
          final start = (part.partNumber - 1) * partSize;
          if (start >= source.length) {
            throw Exception('Media multipart plan exceeds the selected file.');
          }
          final endExclusive = math.min(start + partSize, source.length);
          final etag = await uploadTransport.putRange(
            url: Uri.parse(part.url),
            headers: part.headers,
            source: source,
            start: start,
            endExclusive: endExclusive,
          );
          if (etag == null || etag.trim().isEmpty) {
            throw Exception(
              'Object storage did not return an ETag for part ${part.partNumber}.',
            );
          }
          receipts.add(<String, Object>{
            'part_number': part.partNumber,
            'etag': etag,
          });
        }
      } else if (plan.uploadMode == 'single_put' ||
          plan.uploadMode == 'local_stream') {
        final uploadUrl = plan.uploadUrl;
        if (uploadUrl == null || uploadUrl.trim().isEmpty) {
          throw Exception('Media server did not return an upload URL.');
        }
        final headers = <String, String>{...plan.uploadHeaders};
        if (plan.uploadMode == 'local_stream') {
          headers['Authorization'] = 'Bearer $token';
        }
        await uploadTransport.putRange(
          url: Uri.parse(uploadUrl),
          headers: headers,
          source: source,
          start: 0,
          endExclusive: source.length,
        );
      } else {
        throw Exception(
          'Unsupported media upload mode: ${plan.uploadMode}.',
        );
      }

      final completed = await network.postMap(
        '/media/upload-sessions/${plan.sessionId}/complete',
        headers: authHeaders,
        body: <String, Object>{'parts': receipts},
      );
      final initial = MediaUploadResult.fromJson(completed);
      return _waitUntilUsable(
        network,
        headers: authHeaders,
        initial: initial,
      );
    } finally {
      uploadTransport.close();
      network.close();
    }
  }

  Future<MediaUploadResult> _waitUntilUsable(
    AppNetworkClient network, {
    required Map<String, String> headers,
    required MediaUploadResult initial,
  }) async {
    var current = initial;
    final deadline = DateTime.now().add(const Duration(minutes: 6));

    while (true) {
      if (current.uploadStatus == 'approved') return current;

      if (current.uploadStatus == 'processing_failed' ||
          current.uploadStatus == 'rejected') {
        throw Exception('Media processing failed. Please try another file.');
      }
      if (current.uploadStatus == 'quarantined' ||
          current.moderationStatus == 'ai_flagged' ||
          current.moderationStatus == 'human_rejected') {
        throw Exception('Media could not be approved for this surface.');
      }
      if (current.moderationStatus == 'human_review_required') {
        throw Exception(
          'Media is pending safety review. Please try again after review.',
        );
      }
      if (DateTime.now().isAfter(deadline)) {
        throw Exception('Media is still processing. Please try again shortly.');
      }

      await Future<void>.delayed(const Duration(seconds: 1));
      final status = await network.getMap(
        '/media/${current.mediaId}/status',
        headers: headers,
      );
      current = MediaUploadResult.fromJson(status);
    }
  }

  String _safeFilename(String raw, {String fallbackExtension = '.bin'}) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final extension = fallbackExtension.trim().isEmpty
        ? '.bin'
        : fallbackExtension.trim();
    if (cleaned.isEmpty) return 'funkey_media$extension';
    return cleaned.contains('.') ? cleaned : '$cleaned$extension';
  }

  String _contentType(String filename, {String? declared}) {
    final safeDeclared = (declared ?? '').split(';').first.trim().toLowerCase();
    if (safeDeclared.isNotEmpty &&
        safeDeclared != 'application/octet-stream') {
      return safeDeclared;
    }

    final lower = filename.toLowerCase();
    const mapping = <String, String>{
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.webp': 'image/webp',
      '.gif': 'image/gif',
      '.mp4': 'video/mp4',
      '.webm': 'video/webm',
      '.mov': 'video/quicktime',
      '.mp3': 'audio/mpeg',
      '.m4a': 'audio/mp4',
      '.aac': 'audio/aac',
      '.wav': 'audio/wav',
      '.ogg': 'audio/ogg',
      '.oga': 'audio/ogg',
      '.opus': 'audio/ogg',
      '.weba': 'audio/webm',
      '.flac': 'audio/flac',
      '.pdf': 'application/pdf',
      '.txt': 'text/plain',
      '.csv': 'text/csv',
      '.doc': 'application/msword',
      '.docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.zip': 'application/zip',
    };
    for (final entry in mapping.entries) {
      if (lower.endsWith(entry.key)) return entry.value;
    }
    return 'application/octet-stream';
  }
}

class MediaUploadPlanPart {
  const MediaUploadPlanPart({
    required this.partNumber,
    required this.url,
    required this.headers,
  });

  final int partNumber;
  final String url;
  final Map<String, String> headers;

  factory MediaUploadPlanPart.fromJson(Map<String, dynamic> json) {
    return MediaUploadPlanPart(
      partNumber: _int(json['part_number']),
      url: json['url']?.toString() ?? '',
      headers: _stringMap(json['headers']),
    );
  }
}

class MediaUploadPlan {
  const MediaUploadPlan({
    required this.sessionId,
    required this.mediaId,
    required this.uploadMode,
    required this.uploadUrl,
    required this.uploadHeaders,
    required this.partSizeBytes,
    required this.parts,
  });

  final String sessionId;
  final String mediaId;
  final String uploadMode;
  final String? uploadUrl;
  final Map<String, String> uploadHeaders;
  final int? partSizeBytes;
  final List<MediaUploadPlanPart> parts;

  factory MediaUploadPlan.fromJson(Map<String, dynamic> json) {
    return MediaUploadPlan(
      sessionId: json['session_id']?.toString() ?? '',
      mediaId: json['media_id']?.toString() ?? '',
      uploadMode: json['upload_mode']?.toString() ?? '',
      uploadUrl: json['upload_url']?.toString(),
      uploadHeaders: _stringMap(json['upload_headers']),
      partSizeBytes: json['part_size_bytes'] == null
          ? null
          : _int(json['part_size_bytes']),
      parts: (json['parts'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(MediaUploadPlanPart.fromJson)
          .toList(growable: false),
    );
  }
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.url,
    required this.mediaType,
    required this.contentType,
    required this.sizeBytes,
    this.mediaId = '',
    this.uploadStatus = '',
    this.processingStatus = '',
    this.moderationStatus = '',
  });

  final String url;
  final String mediaType;
  final String contentType;
  final int sizeBytes;
  final String mediaId;
  final String uploadStatus;
  final String processingStatus;
  final String moderationStatus;

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    final contentType = json['content_type']?.toString() ?? '';
    return MediaUploadResult(
      url: json['url']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ??
          _kindForContentType(contentType),
      contentType: contentType,
      sizeBytes: _int(json['size_bytes']),
      mediaId: json['media_id']?.toString() ?? '',
      uploadStatus: json['upload_status']?.toString() ?? '',
      processingStatus: json['processing_status']?.toString() ?? '',
      moderationStatus: json['moderation_status']?.toString() ?? '',
    );
  }
}

String _kindForContentType(String contentType) {
  if (contentType.startsWith('video/')) return 'video';
  if (contentType.startsWith('audio/')) return 'audio';
  if (contentType.startsWith('image/')) return 'image';
  return 'document';
}

Map<String, String> _stringMap(dynamic value) {
  if (value is! Map) return const <String, String>{};
  return <String, String>{
    for (final entry in value.entries)
      entry.key.toString(): entry.value.toString(),
  };
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
