import 'package:flutter/foundation.dart';

/// Google Sign-In client configuration for local web, Android debug, and future release builds.
///
/// Pass these at run time instead of hard-coding secrets/client IDs into the app:
///
/// Web / laptop Chrome:
/// flutter run -d chrome --web-port=5000 \
///   --dart-define=VM_GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
///
/// Android phone/emulator:
/// flutter run -d android \
///   --dart-define=VM_GOOGLE_ANDROID_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
///
/// Important:
/// - The Android OAuth client is matched by package name + SHA in Firebase/Google Cloud.
/// - serverClientId should usually be the WEB client ID so Android returns an ID token
///   whose aud can be verified by the backend.
/// - The backend .env GOOGLE_AUTH_CLIENT_IDS should include the same allowed client IDs.
abstract final class GoogleSignInConfig {
  static const String webClientId = String.fromEnvironment(
    'VM_GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  static const String androidServerClientId = String.fromEnvironment(
    'VM_GOOGLE_ANDROID_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  static String? get clientId {
    final trimmed = webClientId.trim();
    if (kIsWeb && trimmed.isNotEmpty) return trimmed;
    return null;
  }

  static String? get serverClientId {
    final trimmed = androidServerClientId.trim();
    if (!kIsWeb && trimmed.isNotEmpty) return trimmed;
    return null;
  }

  static String get setupHint {
    if (kIsWeb) {
      return 'For laptop Chrome, run with --web-port=5000 and --dart-define=VM_GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com. Add http://localhost:5000 and http://127.0.0.1:5000 as authorized JavaScript origins in Google Cloud.';
    }
    return 'For Android, add the app package name plus SHA-1/SHA-256 in Firebase/Google Cloud, download android/app/google-services.json, and run with --dart-define=VM_GOOGLE_ANDROID_SERVER_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com.';
  }
}
