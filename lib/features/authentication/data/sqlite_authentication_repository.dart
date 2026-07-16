import '../domain/authentication_repository.dart';

/// Local authentication placeholder. No credentials are persisted in SQLite.
class SqliteAuthenticationRepository implements AuthenticationRepository {
  @override
  Future<void> requestOtp(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<bool> verifyOtp({required String email, required String otp}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return otp.length == 6;
  }

  @override
  Future<bool> signInWithGoogle() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return true;
  }

  @override
  Future<void> signOut() async {}
}
