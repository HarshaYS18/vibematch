import 'package:flutter/foundation.dart';

/// Google Sign-In client configuration for local web, Android debug, and future release builds.
///
/// Google OAuth client IDs are public identifiers, not secrets. The fallback below is the
/// same web client ID allowed by the backend GOOGLE_AUTH_CLIENT_IDS in local .env.
/// It prevents Google login from silently breaking when --dart-define is forgotten.
///
/// Web / laptop Chrome:
/// flutter run -d chrome --web-port=5000
///
/// Optional override:
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
  static const String _defaultWebClientId =
      '112046889240-db25nkdrkv5i0qtcveo878g3e9v8gctb.apps.googleusercontent.com';

  static const String webClientId = String.fromEnvironment(
    'VM_GOOGLE_WEB_CLIENT_ID',
    defaultValue: _defaultWebClientId,
  );

  static const String androidServerClientId = String.fromEnvironment(
    'VM_GOOGLE_ANDROID_SERVER_CLIENT_ID',
    defaultValue: _defaultWebClientId,
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
      return 'For laptop Chrome, run with --web-port=5000. In Google Cloud, add http://localhost:5000 and http://127.0.0.1:5000 as authorized JavaScript origins for the web client ID.';
    }
    return 'For Android, add the app package name plus SHA-1/SHA-256 in Firebase/Google Cloud, download android/app/google-services.json, and keep VM_GOOGLE_ANDROID_SERVER_CLIENT_ID set to the web client ID if overriding.';
  }
}
