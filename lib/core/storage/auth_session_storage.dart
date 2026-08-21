abstract class AuthSessionStorage {
  String? readUserEmail();
  Future<void> writeUserEmail(String? email);
}
