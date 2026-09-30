import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'tools/seed_demo_ravi_kumar.dart';
import 'tools/seed_demo_kiruthika.dart';
import 'tools/seed_all_employees_attendance.dart';
import 'tools/seed_demo_incentive.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  // Run database sync asynchronously in the background
  _runBackgroundDataSync();
}

void _runBackgroundDataSync() {
  Future.microtask(() async {
    try {
      await seedDemoRaviKumar();
      await seedDemoKiruthika();
      await syncEmployeeJoiningAndAttendance();
      await seedDemoIncentives();
    } catch (e) {
      debugPrint('Background sync notice: $e');
    }
  });
}
