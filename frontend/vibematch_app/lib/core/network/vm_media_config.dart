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

  static String get wsUrl {
    final override = _overrideWsUrl.trim();
    if (override.isNotEmpty) return override;

    final base = VmApiConfig.baseUrl
        .replaceFirst('https://', 'wss://')
        .replaceFirst('http://', 'ws://');
    return '$base/ws/room-realtime';
  }

}
