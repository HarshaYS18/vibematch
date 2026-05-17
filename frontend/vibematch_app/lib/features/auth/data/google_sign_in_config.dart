import 'package:flutter/foundation.dart';

/// Google Sign-In client configuration for FunKey / VibeMatch beta.
///
/// Google OAuth client IDs are public identifiers, not secrets. The fallback below is the
/// same web client ID that the backend GOOGLE_AUTH_CLIENT_IDS must allow.
///
/// Local web testing origin:
/// http://localhost:5000
///
/// Early beta VPS web origin:
/// http://140.245.215.16:5000
///
/// Android:
/// - The Android OAuth client is matched by package name + SHA in Firebase/Google Cloud.
/// - serverClientId should be the WEB client ID so Android returns an ID token
///   whose aud can be verified by the backend.
/// - The backend .env GOOGLE_AUTH_CLIENT_IDS should include the same web client ID.
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
      return 'For local web testing, run with --web-port=5000 and add http://localhost:5000 as an authorized JavaScript origin in Google Cloud for the web client ID. For VPS beta, also add http://140.245.215.16:5000.';
    }
    return 'For Android beta, add the app package name plus SHA-1/SHA-256 in Firebase/Google Cloud, download android/app/google-services.json, and keep the Android server client ID equal to the web client ID.';
  }
}