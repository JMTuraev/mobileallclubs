import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/client_insights_summary.dart';

final clientInsightsProvider =
    FutureProvider.family<ClientInsightsSummary?, String>((
      ref,
      clientId,
    ) async {
      final session = ref.watch(bootstrapControllerProvider).session;
      if (!_canLoadClientInsights(session, clientId)) {
        return null;
      }

      final result = await ref
          .watch(firebaseFunctionsProvider)
          .httpsCallable('getClientInsights')
          .call({'clientId': clientId.trim()});

      final data = result.data;
      if (data is! Map) {
        throw Exception(
          'Unexpected getClientInsights response: ${data.runtimeType}',
        );
      }

      return ClientInsightsSummary.fromMap(
        data['id']?.toString() ?? clientId.trim(),
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    });

bool _canLoadClientInsights(ResolvedAuthSession? session, String clientId) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return clientId.trim().isNotEmpty &&
      gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}
