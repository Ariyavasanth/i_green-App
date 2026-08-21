import 'auth_session_storage.dart';
import 'auth_session_storage_stub.dart'
    if (dart.library.html) 'auth_session_storage_web.dart';

AuthSessionStorage createAuthSessionStorage() => createAuthSessionStorageImpl();
