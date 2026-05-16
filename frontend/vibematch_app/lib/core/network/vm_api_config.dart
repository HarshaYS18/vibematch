import 'package:flutter/foundation.dart';

/// Central API endpoint config for FunKey / VibeMatch frontend.
///
/// Early beta default points to the VPS public IP:
/// http://140.245.215.16:8000
///
/// Optional overrides:
/// - Local backend: --dart-define=VM_API_BASE_URL=http://127.0.0.1:8000
/// - Android emulator: --dart-define=VM_API_ENV=androidEmulator
/// - Any custom host: --dart-define=VM_API_BASE_URL=http://YOUR_HOST:8000
abstract final class VmApiConfig {
  static const String betaVpsHost = '140.245.215.16';
  static const String betaVpsBaseUrl = 'http://$betaVpsHost:8000';

  static const String _overrideBaseUrl = String.fromEnvironment(
    'VM_API_BASE_URL',
    defaultValue: '',
  );

  static const String _apiEnv = String.fromEnvironment(
    'VM_API_ENV',
    defaultValue: 'vpsBeta',
  );

  static String get baseUrl {
    final override = _overrideBaseUrl.trim();
    if (override.isNotEmpty) return _withoutTrailingSlash(override);

    if (_apiEnv == 'androidEmulator') {
      return 'http://10.0.2.2:8000';
    }

    if (_apiEnv == 'local') {
      return 'http://127.0.0.1:8000';
    }

    return betaVpsBaseUrl;
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
