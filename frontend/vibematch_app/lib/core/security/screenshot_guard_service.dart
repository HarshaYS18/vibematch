import 'package:flutter/services.dart';

class ScreenshotGuardService {
  const ScreenshotGuardService._();

  static const MethodChannel _channel = MethodChannel('vibematch/screenshot_guard');
  static bool _blocked = false;

  static bool get isBlocked => _blocked;

  static Future<void> applyRoomScreenshotPolicy({required bool allowScreenshots}) async {
    await setScreenshotBlocked(!allowScreenshots);
  }

  static Future<void> setScreenshotBlocked(bool blocked) async {
    if (_blocked == blocked) return;
    _blocked = blocked;
    try {
      await _channel.invokeMethod<void>('setScreenshotBlocked', <String, Object?>{
        'blocked': blocked,
      });
    } on MissingPluginException {
      // Unsupported platform or hot-restart before native channel is ready.
    } on PlatformException {
      // Screenshot guard must never crash room entry.
    }
  }

  static Future<void> clear() => setScreenshotBlocked(false);
}
