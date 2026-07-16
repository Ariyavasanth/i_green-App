abstract interface class AuthenticationRepository {
  Future<void> requestOtp(String email);

  Future<bool> verifyOtp({required String email, required String otp});

  Future<bool> signInWithGoogle();

  Future<void> signOut();
}
