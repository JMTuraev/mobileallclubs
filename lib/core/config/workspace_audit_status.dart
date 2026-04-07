import 'package:flutter_riverpod/flutter_riverpod.dart';

class WorkspaceAuditStatus {
  const WorkspaceAuditStatus({
    required this.productionSpecAvailable,
    required this.verifiedFacts,
    required this.missingArtifacts,
    required this.preparedDocs,
    required this.placeholderArtifacts,
  });

  final bool productionSpecAvailable;
  final List<String> verifiedFacts;
  final List<String> missingArtifacts;
  final List<String> preparedDocs;
  final List<String> placeholderArtifacts;
}

final workspaceAuditStatusProvider = Provider<WorkspaceAuditStatus>(
  (ref) => const WorkspaceAuditStatus(
    productionSpecAvailable: false,
    verifiedFacts: [
      'Flutter mobile scaffold exists under lib/ with GoRouter and Riverpod.',
      'pubspec.yaml now declares firebase_core, firebase_auth, cloud_firestore, and cloud_functions.',
      'Android Firebase bootstrap is configured from android/app/google-services.json.',
      'Android package alignment now targets uz.allclubs.app.',
      'iOS still requires the real GoogleService-Info.plist for Firebase startup.',
      'No website, backend, Cloud Functions, Firestore rules, or production business modules are present in this workspace.',
    ],
    missingArtifacts: [
      'Existing AllClubs website source',
      'Backend or Cloud Functions source',
      'Firestore rules and indexes',
      'Production role and gym resolution logic',
      'Billing verification implementation',
    ],
    preparedDocs: [
      'docs/mobile_full_parity_audit.md',
      'docs/mobile_parity_matrix.md',
      'docs/mobile_role_permissions_matrix.md',
      'docs/mobile_backend_reuse_plan.md',
      'docs/mobile_gap_report.md',
      'docs/mobile_release_plan.md',
      'docs/mobile_test_plan.md',
      'docs/mobile_billing_architecture.md',
      'docs/mobile_ui_system.md',
    ],
    placeholderArtifacts: [
      'lib/features/dashboard/presentation/dashboard_screen.dart',
      'lib/features/clients/presentation/clients_screen.dart',
      'lib/features/sessions/presentation/sessions_screen.dart',
      'lib/features/more/presentation/more_screen.dart',
      'lib/features/shell/presentation/foundation_shell.dart',
      'lib/core/widgets/foundation_page.dart',
      'lib/core/widgets/module_status_card.dart',
      'lib/core/widgets/status_pill.dart',
      'lib/models/module_readiness_status.dart',
    ],
  ),
);
