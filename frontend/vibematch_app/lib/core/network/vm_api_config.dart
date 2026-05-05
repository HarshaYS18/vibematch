import 'package:flutter/foundation.dart';

/// Central API endpoint config for VibeMatch frontend.
///
/// Defaults:
/// - Flutter Web / Windows / macOS / Linux local testing: http://127.0.0.1:8000
/// - Android emulator can be selected with --dart-define=VM_API_ENV=androidEmulator
/// - Physical phone/LAN can be selected with --dart-define=VM_API_BASE_URL=http://YOUR_LAN_IP:8000
///
/// Examples:
/// flutter run -d edge --dart-define=VM_API_BASE_URL=http://127.0.0.1:8000
/// flutter run -d android --dart-define=VM_API_ENV=androidEmulator
/// flutter run -d android --dart-define=VM_API_BASE_URL=http://192.168.29.240:8000
abstract final class VmApiConfig {
  static const String _overrideBaseUrl = String.fromEnvironment(
    'VM_API_BASE_URL',
    defaultValue: '',
  );

  static const String _apiEnv = String.fromEnvironment(
    'VM_API_ENV',
    defaultValue: '',
  );

  static String get baseUrl {
    final override = _overrideBaseUrl.trim();
    if (override.isNotEmpty) return _withoutTrailingSlash(override);

    if (_apiEnv == 'androidEmulator') {
      return 'http://10.0.2.2:8000';
    }

    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    }

    return 'http://127.0.0.1:8000';
  }

  static String endpoint(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalizedPath';
  }

  static String _withoutTrailingSlash(String value) {
    var next = value;
    while (next.endsWith('/')) {
      next = next.substring(0, next.length - 1);
    }
    return next;
  }
}
