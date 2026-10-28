import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session_storage.dart';

AuthSessionStorage createAuthSessionStorageImpl() =>
    SharedPreferencesAuthSessionStorage();

Future<void> initAuthSessionStorageImpl() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    SharedPreferencesAuthSessionStorage.setPrefs(prefs);
  } catch (_) {}
}

class SharedPreferencesAuthSessionStorage implements AuthSessionStorage {
  static const _key = 'auth_user_email';
  static SharedPreferences? _prefs;
  static String? _memoryFallback;

  static void setPrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }

  @override
  String? readUserEmail() {
    return _prefs?.getString(_key) ?? _memoryFallback;
  }

  @override
  Future<void> writeUserEmail(String? email) async {
    _memoryFallback = email;
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      if (email == null || email.trim().isEmpty) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, email.trim());
      }
    } catch (_) {}
  }
}
