import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void initializeDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    // Desktop platforms need an explicit FFI-backed sqflite factory.
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
