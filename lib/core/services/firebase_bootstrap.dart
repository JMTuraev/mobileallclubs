import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

enum FirebaseBootstrapStatus {
  initialized,
  configurationBlocked,
  unsupportedPlatform,
  initializationFailed,
}

class FirebaseBootstrapResult {
  const FirebaseBootstrapResult._({
    required this.status,
    required this.message,
  });

  const FirebaseBootstrapResult.initialized()
    : this._(
        status: FirebaseBootstrapStatus.initialized,
        message: 'Firebase initialized successfully.',
      );

  const FirebaseBootstrapResult.configurationBlocked(String message)
    : this._(
        status: FirebaseBootstrapStatus.configurationBlocked,
        message: message,
      );

  const FirebaseBootstrapResult.unsupportedPlatform(String message)
    : this._(
        status: FirebaseBootstrapStatus.unsupportedPlatform,
        message: message,
      );

  const FirebaseBootstrapResult.initializationFailed(String message)
    : this._(
        status: FirebaseBootstrapStatus.initializationFailed,
        message: message,
      );

  final FirebaseBootstrapStatus status;
  final String message;

  bool get isInitialized => status == FirebaseBootstrapStatus.initialized;
}

class FirebaseBootstrap {
  static FirebaseBootstrapResult _lastResult =
      const FirebaseBootstrapResult.configurationBlocked(
        'Firebase bootstrap has not run yet.',
      );

  static FirebaseBootstrapResult get lastResult => _lastResult;

  static Future<FirebaseBootstrapResult> ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      _storeResult(const FirebaseBootstrapResult.initialized());
      return _lastResult;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      await _activateAppCheck();
      await _wireCrashlytics();

      _storeResult(const FirebaseBootstrapResult.initialized());
      return _lastResult;
    } on UnsupportedError catch (error) {
      _storeResult(
        FirebaseBootstrapResult.configurationBlocked(
          error.message?.toString() ?? error.toString(),
        ),
      );
      return _lastResult;
    } on FirebaseException catch (error) {
      _storeResult(
        FirebaseBootstrapResult.initializationFailed(
          error.message ?? error.code,
        ),
      );
      return _lastResult;
    }
  }

  static Future<void> _activateAppCheck() async {
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    } on FirebaseException catch (error, stack) {
      // App Check failure must not block startup; surface to Crashlytics later.
      debugPrint('[FirebaseBootstrap] App Check activation failed: ${error.code}');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'firebase_bootstrap',
          context: ErrorDescription('activating Firebase App Check'),
        ),
      );
    }
  }

  static Future<void> _wireCrashlytics() async {
    if (kIsWeb) return;
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      crashlytics.recordFlutterError(details);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  static void _storeResult(FirebaseBootstrapResult result) {
    _lastResult = result;

    if (kDebugMode) {
      debugPrint(
        '[FirebaseBootstrap] ${result.status.name}: ${result.message}',
      );
    }
  }
}

final firebaseBootstrapResultProvider = Provider<FirebaseBootstrapResult>(
  (ref) => FirebaseBootstrap.lastResult,
);
