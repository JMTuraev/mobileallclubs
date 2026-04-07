import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/client_detail_models.dart';

final currentGymClientDocumentProvider =
    StreamProvider.family<GymClientDetail?, String>((ref, clientId) {
      final session = ref.watch(bootstrapControllerProvider).session;
      final gymId = session?.gymId;

      if (!_canReadClientData(session, clientId)) {
        return Stream.value(null);
      }

      final firestore = ref.watch(firebaseFirestoreProvider);

      return firestore
          .collection('gyms')
          .doc(gymId)
          .collection('clients')
          .doc(clientId)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) {
              return null;
            }

            return GymClientDetail.fromSnapshot(snapshot);
          });
    });

final currentGymSubscriptionsProvider =
    StreamProvider<List<ClientSubscriptionSummary>>((ref) {
      final session = ref.watch(bootstrapControllerProvider).session;
      final gymId = session?.gymId;

      if (!_canReadClientCollections(session)) {
        return Stream.value(const <ClientSubscriptionSummary>[]);
      }

      final firestore = ref.watch(firebaseFirestoreProvider);
      final query = firestore
          .collection('gyms')
          .doc(gymId)
          .collection('subscriptions')
          .orderBy('createdAt', descending: true);

      return query.snapshots().map(
        (snapshot) => snapshot.docs
            .map(ClientSubscriptionSummary.fromSnapshot)
            .toList(growable: false),
      );
    });

final currentGymClientSubscriptionsProvider =
    Provider.family<AsyncValue<List<ClientSubscriptionSummary>>, String>((
      ref,
      clientId,
    ) {
      if (!_canReadClientData(
        ref.watch(bootstrapControllerProvider).session,
        clientId,
      )) {
        return const AsyncValue.data(<ClientSubscriptionSummary>[]);
      }

      return ref
          .watch(currentGymSubscriptionsProvider)
          .whenData(
            (subscriptions) => subscriptions
                .where((subscription) => subscription.clientId == clientId)
                .toList(growable: false),
          );
    });

final currentGymSessionsProvider = StreamProvider<List<ClientSessionSummary>>((
  ref,
) {
  final session = ref.watch(bootstrapControllerProvider).session;
  final gymId = session?.gymId;

  if (!_canReadClientCollections(session)) {
    return Stream.value(const <ClientSessionSummary>[]);
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
        .map(ClientSessionSummary.fromSnapshot)
        .toList(growable: false),
  );
});

final currentGymClientSessionsProvider =
    Provider.family<AsyncValue<List<ClientSessionSummary>>, String>((
      ref,
      clientId,
    ) {
      if (!_canReadClientData(
        ref.watch(bootstrapControllerProvider).session,
        clientId,
      )) {
        return const AsyncValue.data(<ClientSessionSummary>[]);
      }

      return ref
          .watch(currentGymSessionsProvider)
          .whenData(
            (sessions) => sessions
                .where((session) => session.clientId == clientId)
                .toList(growable: false),
          );
    });

bool _canReadClientCollections(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

bool _canReadClientData(ResolvedAuthSession? session, String clientId) {
  return clientId.trim().isNotEmpty && _canReadClientCollections(session);
}
