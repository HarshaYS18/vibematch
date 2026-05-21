import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/vm_api_config.dart';
import '../../auth/data/auth_api_service.dart';
import '../presentation/manual_image_crop_page.dart';
import '../presentation/profile_image_crop_page.dart';

class MediaUploadService {
  const MediaUploadService({
    this.authApiService = const AuthApiService(),
    ImagePicker? imagePicker,
  }) : _imagePicker = imagePicker;

  final AuthApiService authApiService;
  final ImagePicker? _imagePicker;

  ImagePicker get imagePicker => _imagePicker ?? ImagePicker();

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery, int imageQuality = 88, double? maxWidth = 1600, double? maxHeight = 1600}) {
    return imagePicker.pickImage(source: source, imageQuality: imageQuality, maxWidth: maxWidth, maxHeight: maxHeight);
  }

  Future<MediaUploadResult> pickCropAndUploadAvatar(BuildContext context) async {
    final file = await pickImage(maxWidth: 2400, maxHeight: 2400, imageQuality: 96);
    if (file == null) throw const MediaUploadCancelledException();
    final bytes = await file.readAsBytes();
    final crop = await Navigator.of(context).push<ManualImageCropResult>(
      MaterialPageRoute(
        builder: (_) => ProfileImageCropPage(
          imageBytes: bytes,
          title: 'Adjust Avatar',
          aspectRatio: 1,
          outputWidth: 512,
          outputHeight: 512,
          helpText: 'Drag and pinch to frame your face like Bigo. Final avatar is saved as 512×512 for profile, mini-card and live room seats.',
        ),
      ),
    );
    if (crop == null) throw const MediaUploadCancelledException();
    final cropped = _manualCropJpeg(bytes: bytes, crop: crop);
    return _uploadBytes(bytes: cropped, filename: 'vibematch_avatar.jpg', endpointPath: '/media/avatar', failedMessage: 'Failed to upload avatar');
  }

  Future<MediaUploadResult> pickCropAndUploadProfileCover(BuildContext context) async {
    final file = await pickImage(maxWidth: 3200, maxHeight: 2200, imageQuality: 96);
    if (file == null) throw const MediaUploadCancelledException();
    final bytes = await file.readAsBytes();
    final crop = await Navigator.of(context).push<ManualImageCropResult>(
      MaterialPageRoute(
        builder: (_) => ProfileImageCropPage(
          imageBytes: bytes,
          title: 'Adjust Cover',
          aspectRatio: 16 / 9,
          outputWidth: 1600,
          outputHeight: 900,
          helpText: 'Drag and pinch to place the cover exactly. Final cover is saved as 1600×900 for profile headers and CDN delivery.',
        ),
      ),
    );
    if (crop == null) throw const MediaUploadCancelledException();
    final cropped = _manualCropJpeg(bytes: bytes, crop: crop);
    return _uploadBytes(bytes: cropped, filename: 'vibematch_cover.jpg', endpointPath: '/media/profile-cover', failedMessage: 'Failed to upload cover');
  }

  Future<MediaUploadResult> pickCropAndUploadRoomCover(BuildContext context) async {
    final file = await pickImage(maxWidth: 2400, maxHeight: 1800, imageQuality: 96);
    if (file == null) throw const MediaUploadCancelledException();
    final bytes = await file.readAsBytes();
    final crop = await Navigator.of(context).push<ManualImageCropResult>(
      MaterialPageRoute(
        builder: (_) => ManualImageCropPage(
          imageBytes: bytes,
          title: 'Crop Room Cover',
          aspectRatio: 16 / 9,
          outputWidth: 1280,
          outputHeight: 720,
          helpText: 'Move and pinch zoom the image inside the grid. Chatroom cover photos use a 16:9 crop and save as 1280×720 for home cards and live room previews.',
        ),
      ),
    );
    if (crop == null) throw const MediaUploadCancelledException();
    final cropped = _manualCropJpeg(bytes: bytes, crop: crop);
    return _uploadBytes(bytes: cropped, filename: 'vibematch_room_cover.jpg', endpointPath: '/media/room-avatar', failedMessage: 'Failed to upload room cover');
  }

  Future<MediaUploadResult> pickCropAndUploadHomeBanner(BuildContext context, {required String title, required double aspectRatio, required int outputWidth, required int outputHeight}) async {
    final file = await pickImage(maxWidth: 2600, maxHeight: 1800, imageQuality: 96);
    if (file == null) throw const MediaUploadCancelledException();
    final bytes = await file.readAsBytes();
    final crop = await Navigator.of(context).push<ManualImageCropResult>(
      MaterialPageRoute(
        builder: (_) => ManualImageCropPage(imageBytes: bytes, title: title, aspectRatio: aspectRatio, outputWidth: outputWidth, outputHeight: outputHeight, helpText: 'Move and pinch zoom the image inside the grid. The final crop is saved as $outputWidth×$outputHeight for crisp CDN-ready home banners.'),
      ),
    );
    if (crop == null) throw const MediaUploadCancelledException();
    final cropped = _manualCropJpeg(bytes: bytes, crop: crop);
    return _uploadBytes(bytes: cropped, filename: 'vibematch_home_banner.jpg', endpointPath: '/media/home-banner', failedMessage: 'Failed to upload home banner');
  }

  Future<MediaUploadResult> pickAndUploadAvatar() async {
    final file = await pickImage(maxWidth: 1200, maxHeight: 1200, imageQuality: 90);
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, endpointPath: '/media/avatar');
  }

  Future<MediaUploadResult> pickAndUploadProfileCover() async {
    final file = await pickImage(maxWidth: 1800, maxHeight: 900, imageQuality: 90);
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, endpointPath: '/media/profile-cover');
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

  Future<MediaUploadResult> uploadImage({required XFile file, required String endpointPath}) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw Exception('Selected image is empty.');
    return _uploadBytes(bytes: bytes, filename: _safeImageFilename(file.name), endpointPath: endpointPath, failedMessage: 'Failed to upload image');
  }

  Future<MediaUploadResult> uploadRoomMusicBytes({required List<int> bytes, required String filename}) async {
    if (bytes.isEmpty) throw Exception('Selected audio is empty.');
    return _uploadBytes(bytes: bytes, filename: _safeAudioFilename(filename), endpointPath: '/media/room-music', failedMessage: 'Failed to upload room music');
  }

  Uint8List _manualCropJpeg({required Uint8List bytes, required ManualImageCropResult crop}) {
    final source = img.decodeImage(bytes);
    if (source == null) throw Exception('Selected image could not be decoded.');
    final safeX = crop.x.clamp(0, max(0, source.width - 1)).toInt();
    final safeY = crop.y.clamp(0, max(0, source.height - 1)).toInt();
    final safeWidth = crop.width.clamp(1, source.width - safeX).toInt();
    final safeHeight = crop.height.clamp(1, source.height - safeY).toInt();
    final cropped = img.copyCrop(source, x: safeX, y: safeY, width: safeWidth, height: safeHeight);
    final resized = img.copyResize(cropped, width: crop.outputWidth, height: crop.outputHeight, interpolation: img.Interpolation.cubic);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
  }

  Future<MediaUploadResult> _uploadBytes({required List<int> bytes, required String filename, required String endpointPath, required String failedMessage}) async {
    final token = authApiService.cachedAccessToken;
    if (token == null || token.trim().isEmpty) throw Exception('Please login again before uploading media.');
    final request = http.MultipartRequest('POST', Uri.parse(VmApiConfig.endpoint(endpointPath)))
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception(_errorMessage(response, fallback: failedMessage));
    return MediaUploadResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  String _safeImageFilename(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'vibematch_image.jpg';
    final safe = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safe.contains('.') ? safe : '$safe.jpg';
  }

  String _safeAudioFilename(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'vibematch_room_music.mp3';
    final safe = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return safe.contains('.') ? safe : '$safe.mp3';
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
  const MediaUploadResult({required this.url, required this.mediaType, required this.contentType, required this.sizeBytes});
  final String url;
  final String mediaType;
  final String contentType;
  final int sizeBytes;
  factory MediaUploadResult.fromJson(Map<String, dynamic> json) => MediaUploadResult(url: json['url']?.toString() ?? '', mediaType: json['media_type']?.toString() ?? 'image', contentType: json['content_type']?.toString() ?? 'image/jpeg', sizeBytes: int.tryParse(json['size_bytes']?.toString() ?? '') ?? 0);
}

class MediaUploadCancelledException implements Exception {
  const MediaUploadCancelledException();
  @override
  String toString() => 'Image selection cancelled.';
}