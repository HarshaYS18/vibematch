/// Central media server endpoint config for VibeMatch WebRTC internal testing.
///
/// Examples:
/// flutter run -d android --dart-define=VM_MEDIA_WS_URL=ws://192.168.1.8:9000/ws
/// flutter run -d chrome --dart-define=VM_MEDIA_WS_URL=ws://127.0.0.1:9000/ws
abstract final class VmMediaConfig {
  static const String _overrideWsUrl = String.fromEnvironment(
    'VM_MEDIA_WS_URL',
    defaultValue: '',
  );

  static const String _mediaEnv = String.fromEnvironment(
    'VM_MEDIA_ENV',
    defaultValue: '',
  );

  static String get wsUrl {
    final override = _overrideWsUrl.trim();
    if (override.isNotEmpty) return override;

    if (_mediaEnv == 'androidEmulator') {
      return 'ws://10.0.2.2:9000/ws';
    }

    return 'ws://127.0.0.1:9000/ws';
  }
}
