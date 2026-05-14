import 'package:shared_preferences/shared_preferences.dart';

class AuthLocalStorage {
  static const String _legacyAccessTokenKey = 'access_token';
  static const String _accessTokenKey = 'vm_auth_access_token';

  Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, token);
    await prefs.setString(_legacyAccessTokenKey, token);
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final currentToken = prefs.getString(_accessTokenKey);
    if (currentToken != null && currentToken.trim().isNotEmpty) {
      return currentToken;
    }

    final legacyToken = prefs.getString(_legacyAccessTokenKey);
    if (legacyToken != null && legacyToken.trim().isNotEmpty) {
      await prefs.setString(_accessTokenKey, legacyToken);
      return legacyToken;
    }

    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_legacyAccessTokenKey);
  }
}
