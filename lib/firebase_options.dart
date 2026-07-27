import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDWFHhjAb_uH-5XMnkF__N29WSkYc71-3M',
    appId: '1:583868776785:web:9d7f2b927ded8c1df6d370',
    messagingSenderId: '583868776785',
    projectId: 'i-green-tech',
    storageBucket: 'i-green-tech.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDWFHhjAb_uH-5XMnkF__N29WSkYc71-3M',
    appId: '1:583868776785:android:9d7f2b927ded8c1df6d370',
    messagingSenderId: '583868776785',
    projectId: 'i-green-tech',
    storageBucket: 'i-green-tech.firebasestorage.app',
  );
}
