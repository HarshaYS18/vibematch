import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_config.dart';

/// Owns the single GoogleSignIn client for the current Flutter isolate.
///
/// Dev-account login must not touch Google Identity Services at all. On web,
/// even calling signOut() initializes GIS, which was producing duplicate
/// google.accounts.id.initialize() warnings during normal two-window testing.
class GoogleSignInSessionService {
  GoogleSignInSessionService._();

  static final GoogleSignInSessionService instance =
      GoogleSignInSessionService._();

  GoogleSignIn? _client;
  bool _googleWasUsed = false;

  GoogleSignIn get _google => _client ??= GoogleSignIn(
        clientId: GoogleSignInConfig.clientId,
        serverClientId: GoogleSignInConfig.serverClientId,
        scopes: const ['email', 'profile'],
      );

  Future<GoogleSignInAccount?> signIn() async {
    _googleWasUsed = true;
    return _google.signIn();
  }

  /// Signs out only if this app isolate actually used Google Sign-In.
  ///
  /// This deliberately does nothing for Founder/Test User sessions.
  Future<void> signOutIfUsed() async {
    if (!_googleWasUsed) return;
    await _google.signOut();
  }

  Future<void> clearGoogleSessionIfUsed() async {
    if (!_googleWasUsed) return;
    await _google.signOut();
    _googleWasUsed = false;
  }
}
