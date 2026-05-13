import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS. Add '
          'ios/Runner/GoogleService-Info.plist for the registered AllClubs '
          'Apple app before enabling Firebase on iOS.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS in this '
          'repo.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows in this '
          'repo.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux in this '
          'repo.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Fuchsia in this '
          'repo.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCIk0PpgK41pCl3EeBqXCn65y02IMe5p1c',
    appId: '1:1047960307680:android:0a8ee87af4811d6a2d0d85',
    messagingSenderId: '1047960307680',
    projectId: 'allclubs',
    storageBucket: 'allclubs.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCIk0PpgK41pCl3EeBqXCn65y02IMe5p1c',
    appId: '1:1047960307680:web:0a8ee87af4811d6a2d0d85',
    messagingSenderId: '1047960307680',
    projectId: 'allclubs',
    authDomain: 'allclubs.firebaseapp.com',
    storageBucket: 'allclubs.firebasestorage.app',
  );
}
