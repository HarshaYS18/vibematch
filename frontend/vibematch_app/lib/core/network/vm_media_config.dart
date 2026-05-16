import 'vm_api_config.dart';

/// Central media server endpoint config for FunKey / VibeMatch beta testing.
///
/// Early beta defaults:
/// - Room realtime websocket: ws://140.245.215.16:8000/ws/room-realtime
/// - Mediasoup audio SFU: http://140.245.215.16:4000
///
/// Optional overrides:
/// flutter run -d android --dart-define=VM_MEDIA_WS_URL=ws://CUSTOM_HOST:8000/ws/room-realtime
/// flutter run -d android --dart-define=VM_AUDIO_URL=http://CUSTOM_HOST:4000
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
      return 'http://10.0.2.2:4000';
    }

    if (_mediaEnv == 'local') {
      return 'http://127.0.0.1:4000';
    }

    return 'http://${VmApiConfig.betaVpsHost}:4000';
  }
}
