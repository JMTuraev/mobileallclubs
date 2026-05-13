import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/services/firebase_bootstrap.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await FirebaseBootstrap.ensureInitialized();
      runApp(const ProviderScope(child: AllClubsMobileApp()));
    },
    (error, stack) {
      if (kIsWeb || kDebugMode) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
        return;
      }
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}
