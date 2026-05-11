import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

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

  Future<MediaUploadResult> _upload({required String endpoint, required File file}) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before uploading media.');
    }

    final request = http.MultipartRequest('POST', Uri.parse(VmApiConfig.endpoint(endpoint)))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Media upload failed (${response.statusCode}): ${response.body}');
    }

    return MediaUploadResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class MediaUploadResult {
  const MediaUploadResult({required this.url, required this.mediaType, required this.contentType, required this.sizeBytes});

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
