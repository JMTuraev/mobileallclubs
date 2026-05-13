import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../routing/app_router.dart';

const bool showDeveloperDiagnosticsShortcut = bool.fromEnvironment(
  'ALLCLUBS_SHOW_DEV_DIAGNOSTICS',
  defaultValue: false,
);

void openDeveloperDiagnostics(BuildContext context) {
  context.push(AppRoutes.firebaseDiagnostics);
}
