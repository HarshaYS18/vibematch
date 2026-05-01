import 'package:image_picker/image_picker.dart';

class PickedVibeImage {
  const PickedVibeImage({
    required this.file,
    required this.sizeBytes,
    required this.extension,
  });

  final XFile file;
  final int sizeBytes;
  final String extension;

  double get sizeMb => sizeBytes / (1024 * 1024);

  String get displayName {
    final name = file.name.trim();
    if (name.isNotEmpty) return name;
    return file.path.split('/').last;
  }
}

class VibeImagePickResult {
  const VibeImagePickResult._({
    this.image,
    this.errorMessage,
    this.cancelled = false,
  });

  factory VibeImagePickResult.success(PickedVibeImage image) {
    return VibeImagePickResult._(image: image);
  }

  factory VibeImagePickResult.failure(String errorMessage) {
    return VibeImagePickResult._(errorMessage: errorMessage);
  }

  factory VibeImagePickResult.cancelled() {
    return const VibeImagePickResult._(cancelled: true);
  }

  final PickedVibeImage? image;
  final String? errorMessage;
  final bool cancelled;

  bool get hasImage => image != null;
  bool get hasError => errorMessage != null && errorMessage!.trim().isNotEmpty;
}

class VibeImagePickerService {
  VibeImagePickerService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  static const int avatarMaxBytes = 10 * 1024 * 1024;
  static const int roomImageMaxBytes = 10 * 1024 * 1024;
  static const int vibeMediaMaxBytes = 20 * 1024 * 1024;

  static const Set<String> supportedImageExtensions = <String>{
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
  };

  Future<VibeImagePickResult> pickImage({
    required ImageSource source,
    required int maxBytes,
    int imageQuality = 92,
  }) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
      );

      if (pickedFile == null) {
        return VibeImagePickResult.cancelled();
      }

      final extension = _extensionFor(pickedFile);
      if (!supportedImageExtensions.contains(extension)) {
        return VibeImagePickResult.failure(
          'Unsupported image type. Use JPG, PNG, WEBP, GIF, HEIC or HEIF.',
        );
      }

      final sizeBytes = await pickedFile.length();
      if (sizeBytes > maxBytes) {
        final maxMb = (maxBytes / (1024 * 1024)).toStringAsFixed(0);
        return VibeImagePickResult.failure(
          'Image is too large. Maximum allowed size is $maxMb MB.',
        );
      }

      return VibeImagePickResult.success(
        PickedVibeImage(
          file: pickedFile,
          sizeBytes: sizeBytes,
          extension: extension,
        ),
      );
    } catch (error) {
      return VibeImagePickResult.failure(
        'Could not pick image. Please check app permissions and try again.',
      );
    }
  }

  String _extensionFor(XFile file) {
    final fromName = file.name.trim().toLowerCase();
    final source = fromName.isNotEmpty ? fromName : file.path.toLowerCase();
    final dotIndex = source.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == source.length - 1) {
      return '';
    }

    return source.substring(dotIndex + 1).split('?').first;
  }
}
