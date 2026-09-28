import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../auth/data/auth_api_service.dart';
import 'media_upload_api_service.dart';
import '../presentation/manual_image_crop_page.dart';
import '../presentation/profile_image_crop_page.dart';

export 'media_upload_api_service.dart' show MediaUploadResult;

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

  Future<MediaUploadResult> pickCropAndUploadAvatar(
    BuildContext context,
  ) async {
    final file = await pickImage(
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 96,
    );
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
          helpText:
              'Drag and pinch to frame your face like Bigo. Final avatar is saved as 512×512 for profile, mini-card and live room seats.',
        ),
      ),
    );
    if (crop == null) throw const MediaUploadCancelledException();
    final cropped = await _manualCropJpeg(bytes: bytes, crop: crop);
    return _uploadBytes(
      purpose: 'avatar',
      bytes: cropped,
      filename: 'vibematch_avatar.jpg',
    );
  }

  Future<MediaUploadResult> pickCropAndUploadProfileCover(
    BuildContext context,
  ) async {
    final file = await pickImage(
      maxWidth: 3200,
      maxHeight: 2200,
      imageQuality: 96,
    );
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
          helpText:
              'Drag and pinch to place the cover exactly. Final cover is saved as 1600×900 for profile headers and CDN delivery.',
        ),
      ),
    );
    if (crop == null) throw const MediaUploadCancelledException();
    final cropped = await _manualCropJpeg(bytes: bytes, crop: crop);
    return _uploadBytes(
      purpose: 'profile_cover',
      bytes: cropped,
      filename: 'vibematch_cover.jpg',
    );
  }

  Future<MediaUploadResult> pickCropAndUploadRoomCover(
    BuildContext context,
  ) async {
    final file = await pickImage(
      maxWidth: 2400,
      maxHeight: 1800,
      imageQuality: 96,
    );
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
          helpText:
              'Move and pinch zoom the image inside the grid. Chatroom cover photos use a 16:9 crop and save as 1280×720 for home cards and live room previews.',
        ),
      ),
    );
    if (crop == null) throw const MediaUploadCancelledException();
    final cropped = await _manualCropJpeg(bytes: bytes, crop: crop);
    return _uploadBytes(
      purpose: 'room_cover',
      bytes: cropped,
      filename: 'vibematch_room_cover.jpg',
    );
  }

  Future<MediaUploadResult> pickCropAndUploadHomeBanner(
    BuildContext context, {
    required String title,
    required double aspectRatio,
    required int outputWidth,
    required int outputHeight,
  }) async {
    final file = await pickImage(
      maxWidth: 2600,
      maxHeight: 1800,
      imageQuality: 96,
    );
    if (file == null) throw const MediaUploadCancelledException();
    final bytes = await file.readAsBytes();
    final crop = await Navigator.of(context).push<ManualImageCropResult>(
      MaterialPageRoute(
        builder: (_) => ManualImageCropPage(
          imageBytes: bytes,
          title: title,
          aspectRatio: aspectRatio,
          outputWidth: outputWidth,
          outputHeight: outputHeight,
          helpText:
              'Move and pinch zoom the image inside the grid. The final crop is saved as $outputWidth×$outputHeight for crisp CDN-ready home banners.',
        ),
      ),
    );
    if (crop == null) throw const MediaUploadCancelledException();
    final cropped = await _manualCropJpeg(bytes: bytes, crop: crop);
    return _uploadBytes(
      purpose: 'home_banner',
      bytes: cropped,
      filename: 'vibematch_home_banner.jpg',
    );
  }

  Future<MediaUploadResult> pickAndUploadAvatar() async {
    final file = await pickImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, purpose: 'avatar');
  }

  Future<MediaUploadResult> pickAndUploadProfileCover() async {
    final file = await pickImage(
      maxWidth: 1800,
      maxHeight: 900,
      imageQuality: 90,
    );
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, purpose: 'profile_cover');
  }

  Future<MediaUploadResult> pickAndUploadRoomAvatar() async {
    final file = await pickImage(
      maxWidth: 1400,
      maxHeight: 1400,
      imageQuality: 90,
    );
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, purpose: 'room_avatar');
  }

  Future<MediaUploadResult> pickAndUploadChatImage() async {
    final file = await pickImage(
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 88,
    );
    if (file == null) throw const MediaUploadCancelledException();
    return uploadImage(file: file, purpose: 'chat_image');
  }

  Future<MediaUploadResult> uploadImage({
    required XFile file,
    required String purpose,
  }) {
    return MediaUploadApiService(
      authApiService: authApiService,
    ).uploadXFile(
      purpose: purpose,
      file: file,
      filename: _safeImageFilename(file.name),
    );
  }

  Future<MediaUploadResult> uploadRoomMusicXFile(
    XFile file, {
    required String filename,
  }) {
    return MediaUploadApiService(
      authApiService: authApiService,
    ).uploadXFile(
      purpose: 'room_music',
      file: file,
      filename: _safeAudioFilename(filename),
    );
  }

  Future<MediaUploadResult> uploadRoomMusicBytes({
    required List<int> bytes,
    required String filename,
  }) {
    return _uploadBytes(
      purpose: 'room_music',
      bytes: bytes,
      filename: _safeAudioFilename(filename),
    );
  }

  Future<Uint8List> _manualCropJpeg({
    required Uint8List bytes,
    required ManualImageCropResult crop,
  }) {
    return compute<Map<String, Object>, Uint8List>(
      _manualCropJpegJob,
      <String, Object>{
        'bytes': bytes,
        'x': crop.x,
        'y': crop.y,
        'width': crop.width,
        'height': crop.height,
        'outputWidth': crop.outputWidth,
        'outputHeight': crop.outputHeight,
      },
    );
  }

  Future<MediaUploadResult> _uploadBytes({
    required String purpose,
    required List<int> bytes,
    required String filename,
  }) {
    return MediaUploadApiService(
      authApiService: authApiService,
    ).uploadBytes(
      purpose: purpose,
      bytes: bytes,
      filename: filename,
    );
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
}

class MediaUploadCancelledException implements Exception {
  const MediaUploadCancelledException();

  @override
  String toString() => 'Image selection cancelled.';
}

Uint8List _manualCropJpegJob(Map<String, Object> payload) {
  final bytes = payload['bytes']! as Uint8List;
  final source = img.decodeImage(bytes);
  if (source == null) {
    throw Exception('Selected image could not be decoded.');
  }

  final x = payload['x']! as int;
  final y = payload['y']! as int;
  final width = payload['width']! as int;
  final height = payload['height']! as int;
  final outputWidth = payload['outputWidth']! as int;
  final outputHeight = payload['outputHeight']! as int;

  final safeX = x.clamp(0, max(0, source.width - 1)).toInt();
  final safeY = y.clamp(0, max(0, source.height - 1)).toInt();
  final safeWidth = width.clamp(1, source.width - safeX).toInt();
  final safeHeight = height.clamp(1, source.height - safeY).toInt();

  final cropped = img.copyCrop(
    source,
    x: safeX,
    y: safeY,
    width: safeWidth,
    height: safeHeight,
  );
  final resized = img.copyResize(
    cropped,
    width: outputWidth,
    height: outputHeight,
    interpolation: img.Interpolation.cubic,
  );
  return Uint8List.fromList(img.encodeJpg(resized, quality: 92));
}
