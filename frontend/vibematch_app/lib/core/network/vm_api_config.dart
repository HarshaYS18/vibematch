/// Central API endpoint config for FunKey / VibeMatch frontend.
///
/// VM_API_BASE_URL is the backend origin, not the versioned API path.
/// Examples:
/// - Local: --dart-define=VM_API_BASE_URL=http://127.0.0.1:8000
/// - Android emulator: --dart-define=VM_API_ENV=androidEmulator
/// - Production: --dart-define=VM_API_BASE_URL=https://api.funkey.example
abstract final class VmApiConfig {
  static const String apiPrefix = '/api/v1';
  static const String betaVpsHost = '140.245.215.16';
  static const String betaVpsOrigin = 'http://$betaVpsHost:8000';

  static const String _overrideBaseUrl = String.fromEnvironment(
    'VM_API_BASE_URL',
    defaultValue: '',
  );

  static const String _apiEnv = String.fromEnvironment(
    'VM_API_ENV',
    defaultValue: 'vpsBeta',
  );

  static const String _overrideRealtimeWsUrl = String.fromEnvironment(
    'VM_REALTIME_WS_URL',
    defaultValue: '',
  );

  static String get originBaseUrl {
    final override = _overrideBaseUrl.trim();
    if (override.isNotEmpty) return _withoutTrailingSlash(override);

    if (_apiEnv == 'androidEmulator') {
      return 'http://10.0.2.2:8000';
    }

    if (_apiEnv == 'local') {
      return 'http://127.0.0.1:8000';
    }

    return betaVpsOrigin;
  }

  /// Canonical versioned API base used by REST/control-plane calls.
  static String get baseUrl => '$originBaseUrl$apiPrefix';

  /// One application WebSocket owned by AppRealtimeHub.
  ///
  /// Production should set VM_REALTIME_WS_URL to the dedicated Go gateway
  /// ingress (for example wss://ws.funkey.example/ws). Local defaults use the
  /// gateway's 8081 port. Mediasoup signaling is configured separately.
  static String get realtimeWebSocketUrl {
    final override = _overrideRealtimeWsUrl.trim();
    if (override.isNotEmpty) return override;

    if (_apiEnv == 'androidEmulator') {
      return 'ws://10.0.2.2:8081/ws';
    }
    if (_apiEnv == 'local') {
      return 'ws://127.0.0.1:8081/ws';
    }
    if (_apiEnv == 'vpsBeta') {
      return 'ws://$betaVpsHost:8081/ws';
    }

    final uri = Uri.parse(originBaseUrl);
    return uri
        .replace(
          scheme: uri.scheme == 'https' ? 'wss' : 'ws',
          path: '/ws',
          query: null,
          fragment: null,
        )
        .toString();
  }

  static String endpoint(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$normalizedPath';
  }

  static String mediaUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('/')) return '$originBaseUrl$trimmed';

    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return trimmed;

    final originUri = Uri.tryParse(originBaseUrl);
    final host = uri.host.toLowerCase();
    final shouldRewriteToConfiguredBackend =
        originUri != null &&
        (host == 'localhost' ||
            host == '127.0.0.1' ||
            host == '0.0.0.0' ||
            host == '10.0.2.2');
    if (!shouldRewriteToConfiguredBackend) return trimmed;

    return originUri
        .replace(
          path: uri.path,
          query: uri.hasQuery ? uri.query : null,
          fragment: uri.hasFragment ? uri.fragment : null,
        )
        .toString();
  }

  static String _withoutTrailingSlash(String value) {
    var next = value;
    while (next.endsWith('/')) {
      next = next.substring(0, next.length - 1);
    }
    return next;
  }
}
