import 'dart:html' as html;

import 'auth_session_storage.dart';

AuthSessionStorage createAuthSessionStorageImpl() => _WebAuthSessionStorage();

class _WebAuthSessionStorage implements AuthSessionStorage {
  static const _key = 'auth_user_email';

  @override
  String? readUserEmail() {
    final value = html.window.localStorage[_key];
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  @override
  Future<void> writeUserEmail(String? email) async {
    if (email == null || email.trim().isEmpty) {
      html.window.localStorage.remove(_key);
    } else {
      html.window.localStorage[_key] = email.trim();
    }
  }
}
