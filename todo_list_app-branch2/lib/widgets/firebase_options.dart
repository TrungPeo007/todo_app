// lib/widgets/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions not supported for this platform.');
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCGJMgF99-DfFFoOn-08fF_LVU9H7muYHg',
    appId: '1:950851667908:android:e801989b34859c06e40691',
    messagingSenderId: '950851667908',
    projectId: 'apptodolist-ac338',
    storageBucket: 'apptodolist-ac338.appspot.com',
  );
}