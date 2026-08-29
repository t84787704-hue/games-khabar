import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return android;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDummy_Replace_With_Real_Key',
    appId: '1:1234567890:android:abcdef1234567890abcdef',
    messagingSenderId: '1234567890',
    projectId: 'games-khabar-dummy',
    storageBucket: 'games-khabar-dummy.appspot.com',
  );
}
