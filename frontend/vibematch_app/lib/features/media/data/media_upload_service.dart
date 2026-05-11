import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';

class MediaUploadService {
  const MediaUploadService({
    this.authApiService = const AuthApiService(),
    ImagePicker? imagePicker,
  }) : _imagePicker = imagePicker;

  final AuthApiService authApiService;
  final ImagePicker? _imagePicker;

  ImagePicker get imagePicker => _imagePicker ?? ImagePicker();

  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
    int imageQuality = 88,
    double? maxWidth = 1600,
    double? maxHeight = 1600,
  }) {
    return imagePicker.pickImage(
      source: source,
      imageQuality: imageQuality,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }

  Future<MediaUploadResult> pickAndUploadAvatar() async {
    final file = await pickImage(maxWidth: 1200, maxHeight: 1200, imageQuality: 90);
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, endpointPath: '/media/avatar');
  }

  Future<MediaUploadResult> pickAndUploadRoomAvatar() async {
    final file = await pickImage(maxWidth: 1400, maxHeight: 1400, imageQuality: 90);
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, endpointPath: '/media/room-avatar');
  }

  Future<MediaUploadResult> pickAndUploadChatImage() async {
    final file = await pickImage(maxWidth: 1800, maxHeight: 1800, imageQuality: 88);
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, endpointPath: '/media/chat-image');
  }

  Future<MediaUploadResult> uploadImage({
    required XFile file,
    required String endpointPath,
  }) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) {
      throw Exception('Please login again before uploading media.');
    }

    final mimeType = _mimeTypeForPath(file.path);
    final request = http.MultipartRequest('POST', Uri.parse(VmApiConfig.endpoint(endpointPath)))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: mimeType == null ? null : _MediaType.parse(mimeType),
        ),
      );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_errorMessage(response, fallback: 'Failed to upload image'));
    }

    return MediaUploadResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  String? _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return null;
  }

  String _errorMessage(http.Response response, {required String fallback}) {
    final body = response.body.trim();
    if (body.isEmpty) return '$fallback (${response.statusCode})';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail']?.toString().trim();
        if (detail != null && detail.isNotEmpty) return detail;
      }
    } catch (_) {
      return body;
    }
    return '$fallback (${response.statusCode})';
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
      contentType: json['content_type']?.toString() ?? 'image/jpeg',
      sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? '') ?? 0,
    );
  }
}

class MediaUploadCancelledException implements Exception {
  const MediaUploadCancelledException();

  @override
  String toString() => 'Image selection cancelled.';
}

class _MediaType implements http.MultipartFile {
  _MediaType._();

  static dynamic parse(String value) {
    final parts = value.split('/');
    if (parts.length != 2) return null;
    return _SimpleMediaType(parts.first, parts.last);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SimpleMediaType {
  const _SimpleMediaType(this.type, this.subtype);

  final String type;
  final String subtype;

  @override
  String toString() => '$type/$subtype';
}
