import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/client_summary.dart';

final currentGymClientsStreamProvider = StreamProvider<List<GymClientSummary>>((
  ref,
) {
  final bootstrapState = ref.watch(bootstrapControllerProvider);
  final session = bootstrapState.session;
  final role = session?.role ?? AllClubsRole.unknown;
  final gymId = session?.gymId;

  final canReadClients =
      gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);

  if (!canReadClients) {
    return Stream.value(const <GymClientSummary>[]);
  }

  final firestore = ref.watch(firebaseFirestoreProvider);
  final query = firestore
      .collection('gyms')
      .doc(gymId)
      .collection('clients')
      .where('isArchived', isEqualTo: false)
      .orderBy('createdAt', descending: true);

  return query.snapshots().map(
    (snapshot) => snapshot.docs
        .map(GymClientSummary.fromSnapshot)
        .toList(growable: false),
  );
});
