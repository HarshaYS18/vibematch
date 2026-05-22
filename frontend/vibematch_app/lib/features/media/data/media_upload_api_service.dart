import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class MediaUploadApiService {
  const MediaUploadApiService({this.authApiService = const AuthApiService()});

  final AuthApiService authApiService;

  Future<MediaUploadResult> uploadAvatar(File file) {
    return _upload(endpoint: '/media/avatar', file: file);
  }

  Future<MediaUploadResult> uploadRoomAvatar(File file) {
    return _upload(endpoint: '/media/room-avatar', file: file);
  }

  Future<MediaUploadResult> uploadVibeMedia(File file) {
    return _upload(endpoint: '/media/vibes', file: file);
  }

  Future<MediaUploadResult> uploadStoryMediaXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Selected story media is empty.');
    return _uploadBytes(
      endpoint: '/media/story',
      bytes: bytes,
      filename: _safeFilename(
        file.name,
        fallbackExtension: _extensionForMime(file.mimeType),
      ),
    );
  }

  Future<MediaUploadResult> uploadChatImage(File file) {
    return _upload(endpoint: '/media/chat-image', file: file);
  }

  Future<MediaUploadResult> uploadChatDocument(File file) {
    return _upload(endpoint: '/media/chat-document', file: file);
  }

  Future<MediaUploadResult> uploadChatVoice(File file) {
    return _upload(endpoint: '/media/chat-voice', file: file);
  }

  Future<MediaUploadResult> uploadVibeMediaXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Selected media is empty.');
    return _uploadBytes(
      endpoint: '/media/vibes',
      bytes: bytes,
      filename: _safeFilename(
        file.name,
        fallbackExtension: _extensionForMime(file.mimeType),
      ),
    );
  }

  Future<MediaUploadResult> uploadChatImageXFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Selected image is empty.');
    return _uploadBytes(
      endpoint: '/media/chat-image',
      bytes: bytes,
      filename: _safeFilename(
        file.name,
        fallbackExtension: _extensionForMime(file.mimeType),
      ),
    );
  }

  Future<MediaUploadResult> uploadChatDocumentBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) throw Exception('Selected document is empty.');
    return _uploadBytes(
      endpoint: '/media/chat-document',
      bytes: bytes,
      filename: _safeFilename(filename),
    );
  }

  Future<MediaUploadResult> uploadChatVoiceBytes({
    required List<int> bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) throw Exception('Selected voice file is empty.');
    return _uploadBytes(
      endpoint: '/media/chat-voice',
      bytes: bytes,
      filename: _safeFilename(filename),
    );
  }

  Future<MediaUploadResult> _upload({
    required String endpoint,
    required File file,
  }) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before uploading media.');
    }

    final request =
        http.MultipartRequest('POST', Uri.parse(VmApiConfig.endpoint(endpoint)))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Media upload failed (${response.statusCode}): ${response.body}',
      );
    }

    return MediaUploadResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<MediaUploadResult> _uploadBytes({
    required String endpoint,
    required List<int> bytes,
    required String filename,
  }) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before uploading media.');
    }

    final request =
        http.MultipartRequest('POST', Uri.parse(VmApiConfig.endpoint(endpoint)))
          ..headers['Authorization'] = 'Bearer $token'
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Media upload failed (${response.statusCode}): ${response.body}',
      );
    }

    return MediaUploadResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  String _safeFilename(String raw, {String fallbackExtension = '.jpg'}) {
    final cleaned = raw.trim().replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final extension = fallbackExtension.trim().isEmpty
        ? '.jpg'
        : fallbackExtension.trim();
    if (cleaned.isEmpty) return 'funkey_media$extension';
    return cleaned.contains('.') ? cleaned : '$cleaned$extension';
  }

  String _extensionForMime(String? mimeType) {
    switch ((mimeType ?? '').toLowerCase().trim()) {
      case 'image/jpeg':
        return '.jpg';
      case 'image/png':
        return '.png';
      case 'image/webp':
        return '.webp';
      case 'image/gif':
        return '.gif';
      case 'video/mp4':
        return '.mp4';
      case 'video/webm':
        return '.webm';
      case 'video/quicktime':
        return '.mov';
      default:
        return '.jpg';
    }
  }
}

class MediaUploadResult {
  const MediaUploadResult({
    required this.url,
    required this.mediaType,
    required this.contentType,
    required this.sizeBytes,
  });

  final String url;
  final String mediaType;
  final String contentType;
  final int sizeBytes;

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      url: json['url']?.toString() ?? '',
      mediaType: json['media_type']?.toString() ?? 'image',
      contentType: json['content_type']?.toString() ?? '',
      sizeBytes: _int(json['size_bytes']),
    );
  }
}

int _int(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
