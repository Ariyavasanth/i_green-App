import '../domain/authentication_repository.dart';

// Firebase placeholder: implement these methods, then change only the provider line.
class FirebaseAuthenticationRepository implements AuthenticationRepository {
  Never _pending() =>
      throw UnimplementedError('Firebase authentication is not configured yet.');

  @override
  Future<void> requestOtp(String email) async => _pending();
  @override
  Future<bool> verifyOtp({required String email, required String otp}) async =>
      _pending();
  @override
  Future<bool> signInWithGoogle() async => _pending();

  @override
  Future<void> signOut() async => _pending();
}
