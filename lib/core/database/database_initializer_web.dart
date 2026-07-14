import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void initializeDatabaseFactory() {
  // Browser builds need the WebAssembly SQLite factory before opening the DB.
  databaseFactory = databaseFactoryFfiWeb;
}
