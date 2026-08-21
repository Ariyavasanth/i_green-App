import 'auth_session_storage.dart';

AuthSessionStorage createAuthSessionStorageImpl() => _MemoryAuthSessionStorage();

class _MemoryAuthSessionStorage implements AuthSessionStorage {
  static String? _userEmail;

  @override
  String? readUserEmail() => _userEmail;

  @override
  Future<void> writeUserEmail(String? email) async {
    _userEmail = email;
  }
}
