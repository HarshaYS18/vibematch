import 'vm_api_config.dart';

/// Central media endpoint config for FunKey / VibeMatch beta testing.
///
/// Official current paths:
/// - Room realtime websocket: FastAPI `/ws/room-realtime` on port 8000.
/// - Mediasoup audio SFU/signaling: `backend_media` on port 4100.
///
/// Optional overrides:
/// flutter run -d edge --dart-define=VM_MEDIA_WS_URL=ws://CUSTOM_HOST:8000/ws/room-realtime
/// flutter run -d edge --dart-define=VM_AUDIO_URL=http://CUSTOM_HOST:4100
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

    if (_mediaEnv == 'androidEmulator') {
      return 'ws://10.0.2.2:8000/ws/room-realtime';
    }

    if (_mediaEnv == 'local') {
      return 'ws://127.0.0.1:8000/ws/room-realtime';
    }

    final base = VmApiConfig.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base/ws/room-realtime';
  }

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
