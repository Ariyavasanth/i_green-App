import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'tools/seed_demo_emp5406.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'tools/setup_payslip_logos.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupPayslipLogosDirect();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Enable offline persistence so Firestore serves data from local cache
    // immediately on subsequent loads — dramatically reduces perceived load time.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase initializeApp notice: $e');
  }

  // Render the Flutter UI immediately so there is zero freeze or delay
  runApp(const ProviderScope(child: BooksApp()));

  // Run database sync asynchronously in the background for Employee 5406
  _runBackgroundDataSync();
}

void _runBackgroundDataSync() {
  Future.microtask(() async {
    try {
      await seedDemoEmp5406();
    } catch (e) {
      debugPrint('Background sync notice: $e');
    }
  });
}
