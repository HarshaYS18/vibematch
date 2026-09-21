import 'vm_api_config.dart';

/// Central realtime endpoint config for FunKey.
///
/// Room and inbox realtime now run through the versioned FastAPI API.
/// Production room audio does not choose an SFU here: the app resolves the
/// assigned media worker through GET /api/v1/rooms/{room_id}/media.
abstract final class VmMediaConfig {
  static const String _overrideWsUrl = String.fromEnvironment(
    'VM_MEDIA_WS_URL',
    defaultValue: '',
  );

  static const String _overrideAudioUrl = String.fromEnvironment(
    'VM_AUDIO_URL',
    defaultValue: '',
  );

  static const String _mediaEnv = String.fromEnvironment(
    'VM_MEDIA_ENV',
    defaultValue: 'vpsBeta',
  );

  static String get wsUrl {
    final override = _overrideWsUrl.trim();
    if (override.isNotEmpty) return override;

    final base = VmApiConfig.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base/ws/room-realtime';
  }

  /// Dev/test-only direct media endpoint. Production live rooms use discovery.
  static String get audioUrl {
    final override = _overrideAudioUrl.trim();
    if (override.isNotEmpty) return override;

    if (_mediaEnv == 'androidEmulator') {
      return 'http://10.0.2.2:4100';
    }

    if (_mediaEnv == 'local') {
      return 'http://127.0.0.1:4100';
    }

    return 'http://${VmApiConfig.betaVpsHost}:4100';
  }
}
