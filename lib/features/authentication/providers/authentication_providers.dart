import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/auth_session_storage.dart';
import '../../../core/storage/auth_session_storage_factory.dart';
import '../data/firebase_authentication_repository.dart';
import '../domain/authentication_repository.dart';

final authSessionStorageProvider = Provider<AuthSessionStorage>(
  (_) => createAuthSessionStorage(),
);

// Changed to Firebase authentication implementation as requested.
final authenticationRepositoryProvider = Provider<AuthenticationRepository>(
  (ref) => FirebaseAuthenticationRepository(),
);

final currentUserEmailProvider = StateProvider<String?>((ref) {
  final storage = ref.read(authSessionStorageProvider);
  return storage.readUserEmail();
});
