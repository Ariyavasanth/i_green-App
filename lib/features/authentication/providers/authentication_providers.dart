import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_authentication_repository.dart';
import '../domain/authentication_repository.dart';

// Changed to Firebase authentication implementation as requested.
final authenticationRepositoryProvider = Provider<AuthenticationRepository>(
  (ref) => FirebaseAuthenticationRepository(),
);

final currentUserEmailProvider = StateProvider<String?>((ref) => 'Saravanan@igreentec.in');
