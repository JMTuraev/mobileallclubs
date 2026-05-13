import 'package:firebase_core/firebase_core.dart';
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
