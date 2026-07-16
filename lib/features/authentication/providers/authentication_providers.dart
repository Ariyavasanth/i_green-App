import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sqlite_authentication_repository.dart';
import '../domain/authentication_repository.dart';

// Change only this line when the Firebase implementation is ready.
final authenticationRepositoryProvider = Provider<AuthenticationRepository>(
  (ref) => SqliteAuthenticationRepository(),
);
