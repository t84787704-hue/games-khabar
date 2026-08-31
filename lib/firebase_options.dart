import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9EAEGzSBEVoMY_p6Pq8uIOk6fvj_QsHg',
    appId: '1:798094452885:android:afc18994563bf03d97139c',
    messagingSenderId: '798094452885',
    projectId: 'games-khabar',
    storageBucket: 'games-khabar.firebasestorage.app',
  );
}