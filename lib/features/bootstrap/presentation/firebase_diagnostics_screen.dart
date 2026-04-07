import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_runtime_diagnostics.dart';
import '../../../core/widgets/app_backdrop.dart';

class FirebaseDiagnosticsScreen extends ConsumerWidget {
  const FirebaseDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagnostics = ref.watch(firebaseRuntimeDiagnosticsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Firebase Diagnostics')),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Developer-only runtime verification',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This screen verifies Firebase client bootstrap only. It does not read business collections or call production functions.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              _DiagnosticsCard(
                title: 'Bootstrap',
                rows: [
                  _DiagnosticsRow(
                    label: 'Platform',
                    value: diagnostics.platformLabel,
                  ),
                  _DiagnosticsRow(
                    label: 'Status',
                    value: diagnostics.bootstrapResult.status.name,
                  ),
                  _DiagnosticsRow(
                    label: 'Message',
                    value: diagnostics.bootstrapResult.message,
                  ),
                  _DiagnosticsRow(
                    label: 'Firebase app ready',
                    value: _yesNo(diagnostics.firebaseAppReady),
                  ),
                ],
              ),
              _DiagnosticsCard(
                title: 'Identifiers',
                rows: [
                  _DiagnosticsRow(
                    label: 'Firebase app name',
                    value: diagnostics.appName ?? 'UNAVAILABLE',
                  ),
                  _DiagnosticsRow(
                    label: 'Firebase projectId',
                    value: diagnostics.projectId ?? 'UNAVAILABLE',
                  ),
                  _DiagnosticsRow(
                    label: 'Firebase appId',
                    value: diagnostics.appId ?? 'UNAVAILABLE',
                  ),
                  _DiagnosticsRow(
                    label: 'Android applicationId',
                    value: diagnostics.configuredAndroidApplicationId,
                  ),
                  _DiagnosticsRow(
                    label: 'iOS bundle identifier',
                    value: diagnostics.configuredIosBundleIdentifier,
                  ),
                  _DiagnosticsRow(
                    label: 'Expected iOS plist path',
                    value: diagnostics.expectedIosPlistPath,
                  ),
                ],
              ),
              _DiagnosticsCard(
                title: 'Client Instances',
                rows: [
                  _DiagnosticsRow(
                    label: 'Auth ready',
                    value: _yesNo(diagnostics.authReady),
                    detail: diagnostics.authMessage,
                  ),
                  _DiagnosticsRow(
                    label: 'Firestore ready',
                    value: _yesNo(diagnostics.firestoreReady),
                    detail: diagnostics.firestoreMessage,
                  ),
                  _DiagnosticsRow(
                    label: 'Functions ready',
                    value: _yesNo(diagnostics.functionsReady),
                    detail: diagnostics.functionsMessage,
                  ),
                ],
              ),
              _DiagnosticsCard(
                title: 'iOS Follow-up',
                rows: [
                  const _DiagnosticsRow(
                    label: 'Missing file',
                    value: 'ios/Runner/GoogleService-Info.plist',
                  ),
                  const _DiagnosticsRow(
                    label: 'Xcode target path',
                    value:
                        'Runner target -> ios/Runner/GoogleService-Info.plist',
                  ),
                  const _DiagnosticsRow(
                    label: 'Required action',
                    value:
                        'Add the real Apple Firebase plist matching the intended Runner bundle identifier.',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard({required this.title, required this.rows});

  final String title;
  final List<_DiagnosticsRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 14),
          for (final row in rows) row,
        ],
      ),
    );
  }
}

class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

String _yesNo(bool value) => value ? 'YES' : 'NO';
