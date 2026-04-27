import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'vibematch_device_id';

  final Uuid _uuid = const Uuid();

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    final existingDeviceId = prefs.getString(_deviceIdKey);
    if (existingDeviceId != null && existingDeviceId.trim().isNotEmpty) {
      return existingDeviceId;
    }

    final newDeviceId = _createDeviceId();
    await prefs.setString(_deviceIdKey, newDeviceId);

    return newDeviceId;
  }

  String _createDeviceId() {
    final installId = _uuid.v4();

    if (kIsWeb) {
      return 'web-install-$installId';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android-install-$installId';

      case TargetPlatform.iOS:
        return 'ios-install-$installId';

      case TargetPlatform.windows:
        return 'windows-install-$installId';

      case TargetPlatform.macOS:
        return 'macos-install-$installId';

      case TargetPlatform.linux:
        return 'linux-install-$installId';

      case TargetPlatform.fuchsia:
        return 'fuchsia-install-$installId';
    }
  }
}