import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_bootstrap.dart';
import 'firebase_clients.dart';

class FirebaseRuntimeDiagnostics {
  const FirebaseRuntimeDiagnostics({
    required this.bootstrapResult,
    required this.platformLabel,
    required this.configuredAndroidApplicationId,
    required this.configuredIosBundleIdentifier,
    required this.expectedIosPlistPath,
    required this.firebaseAppReady,
    required this.authReady,
    required this.firestoreReady,
    required this.functionsReady,
    this.appName,
    this.projectId,
    this.appId,
    this.firebaseAppMessage,
    this.authMessage,
    this.firestoreMessage,
    this.functionsMessage,
  });

  final FirebaseBootstrapResult bootstrapResult;
  final String platformLabel;
  final String configuredAndroidApplicationId;
  final String configuredIosBundleIdentifier;
  final String expectedIosPlistPath;
  final bool firebaseAppReady;
  final bool authReady;
  final bool firestoreReady;
  final bool functionsReady;
  final String? appName;
  final String? projectId;
  final String? appId;
  final String? firebaseAppMessage;
  final String? authMessage;
  final String? firestoreMessage;
  final String? functionsMessage;
}

final firebaseRuntimeDiagnosticsProvider = Provider<FirebaseRuntimeDiagnostics>(
  (ref) {
    final bootstrapResult = ref.watch(firebaseBootstrapResultProvider);

    String? appName;
    String? projectId;
    String? appId;
    String? firebaseAppMessage;
    String? authMessage;
    String? firestoreMessage;
    String? functionsMessage;

    var firebaseAppReady = false;
    var authReady = false;
    var firestoreReady = false;
    var functionsReady = false;

    if (bootstrapResult.isInitialized && Firebase.apps.isNotEmpty) {
      try {
        final app = Firebase.app();
        firebaseAppReady = true;
        appName = app.name;
        projectId = app.options.projectId;
        appId = app.options.appId;
        firebaseAppMessage = 'Firebase.app() available.';
      } catch (error) {
        firebaseAppMessage = error.toString();
      }

      try {
        FirebaseAuth.instance;
        authReady = true;
        authMessage = 'FirebaseAuth.instance created.';
      } catch (error) {
        authMessage = error.toString();
      }

      try {
        FirebaseFirestore.instance;
        firestoreReady = true;
        firestoreMessage = 'FirebaseFirestore.instance created.';
      } catch (error) {
        firestoreMessage = error.toString();
      }

      try {
        firebaseFunctionsInstance(app: Firebase.app());
        functionsReady = true;
        functionsMessage =
            'FirebaseFunctions.instance created for region asia-south1.';
      } catch (error) {
        functionsMessage = error.toString();
      }
    } else {
      const notReadyMessage =
          'Skipped because Firebase bootstrap did not fully initialize.';
      firebaseAppMessage = notReadyMessage;
      authMessage = notReadyMessage;
      firestoreMessage = notReadyMessage;
      functionsMessage = notReadyMessage;
    }

    return FirebaseRuntimeDiagnostics(
      bootstrapResult: bootstrapResult,
      platformLabel: _platformLabel(),
      configuredAndroidApplicationId: 'uz.allclubs.app',
      configuredIosBundleIdentifier: 'com.example.mobileallclubs',
      expectedIosPlistPath: 'ios/Runner/GoogleService-Info.plist',
      firebaseAppReady: firebaseAppReady,
      authReady: authReady,
      firestoreReady: firestoreReady,
      functionsReady: functionsReady,
      appName: appName,
      projectId: projectId,
      appId: appId,
      firebaseAppMessage: firebaseAppMessage,
      authMessage: authMessage,
      firestoreMessage: firestoreMessage,
      functionsMessage: functionsMessage,
    );
  },
);

String _platformLabel() {
  if (kIsWeb) {
    return 'web';
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
