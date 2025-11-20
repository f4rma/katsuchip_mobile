import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        // Fallback to android options for unsupported platforms in this project
        return android;
    }
  }

  // Values copied from android/app/google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDoeeHEJHAOQSh66timbcgcAqY30ACifzc',
    appId: '1:153925385009:android:12b379b069795ce1a4ce10',
    messagingSenderId: '153925385009',
    projectId: 'katsuchip-65298',
    storageBucket: 'katsuchip-65298.firebasestorage.app',
  );
}
