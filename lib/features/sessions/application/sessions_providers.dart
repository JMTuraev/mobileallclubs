import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/gym_session_summary.dart';

final currentGymSessionsStreamProvider =
    StreamProvider<List<GymSessionSummary>>((ref) {
      final session = ref.watch(bootstrapControllerProvider).session;
      final gymId = session?.gymId;

      if (!_canReadSessions(session)) {
        return Stream.value(const <GymSessionSummary>[]);
      }

      final firestore = ref.watch(firebaseFirestoreProvider);
      final query = firestore
          .collection('gyms')
          .doc(gymId)
          .collection('sessions')
          .orderBy('createdAt', descending: true)
          .limit(500);

      return query.snapshots().map(
        (snapshot) => snapshot.docs
            .map(GymSessionSummary.fromSnapshot)
            .toList(growable: false),
      );
    });

final filteredGymSessionsProvider =
    Provider.family<AsyncValue<List<GymSessionSummary>>, String?>((
      ref,
      clientId,
    ) {
      final trimmedClientId = clientId?.trim();

      return ref.watch(currentGymSessionsStreamProvider).whenData((sessions) {
        if (trimmedClientId == null || trimmedClientId.isEmpty) {
          return sessions;
        }

        return sessions
            .where((session) => session.clientId == trimmedClientId)
            .toList(growable: false);
      });
    });

bool _canReadSessions(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}
