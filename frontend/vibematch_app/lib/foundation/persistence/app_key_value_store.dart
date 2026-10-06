import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppKeyValueStore {
  String? readString(String key);
  bool? readBool(String key);
  Future<void> writeString(String key, String value);
  Future<void> writeBool(String key, bool value);
  Future<void> remove(String key);
}

class SharedPreferencesKeyValueStore implements AppKeyValueStore {
  SharedPreferencesKeyValueStore(this._preferences);

  final SharedPreferences _preferences;

  static Future<SharedPreferencesKeyValueStore> create() async {
    return SharedPreferencesKeyValueStore(
      await SharedPreferences.getInstance(),
    );
  }

  @override
  String? readString(String key) => _preferences.getString(key);

  @override
  bool? readBool(String key) => _preferences.getBool(key);

  @override
  Future<void> writeString(String key, String value) async {
    await _preferences.setString(key, value);
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    await _preferences.setBool(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }
}
