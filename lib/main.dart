import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/database_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Configure the native SQLite factory before any repository opens the DB.
  initializeDatabaseFactory();
  runApp(const ProviderScope(child: BooksApp()));
}
