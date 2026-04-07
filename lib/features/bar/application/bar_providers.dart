import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/bar_category_summary.dart';
import '../domain/bar_check_item.dart';
import '../domain/bar_incoming_invoice_summary.dart';
import '../domain/bar_product_summary.dart';
import '../domain/bar_session_check_summary.dart';

final currentGymBarCategoriesProvider =
    StreamProvider<List<BarCategorySummary>>((ref) {
      final session = ref.watch(bootstrapControllerProvider).session;
      final gymId = session?.gymId;

      if (!_canReadBarData(session)) {
        return Stream.value(const <BarCategorySummary>[]);
      }

      final firestore = ref.watch(firebaseFirestoreProvider);
      final query = firestore
          .collection('gyms')
          .doc(gymId)
          .collection('barCategories')
          .where('isActive', isEqualTo: true)
          .orderBy('name');

      return query.snapshots().map(
        (snapshot) => snapshot.docs
            .map(BarCategorySummary.fromSnapshot)
            .toList(growable: false),
      );
    });

final currentGymBarProductsProvider = StreamProvider<List<BarProductSummary>>((
  ref,
) {
  final session = ref.watch(bootstrapControllerProvider).session;
  final gymId = session?.gymId;

  if (!_canReadBarData(session)) {
    return Stream.value(const <BarProductSummary>[]);
  }

  final firestore = ref.watch(firebaseFirestoreProvider);
  final query = firestore
      .collection('gyms')
      .doc(gymId)
      .collection('barProducts')
      .where('isActive', isEqualTo: true)
      .orderBy('name');

  return query.snapshots().map(
    (snapshot) => snapshot.docs
        .map(BarProductSummary.fromSnapshot)
        .toList(growable: false),
  );
});

final barCheckItemsProvider = StreamProvider.family<List<BarCheckItem>, String>(
  (ref, checkId) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final gymId = session?.gymId;

    if (!_canReadBarData(session) || checkId.trim().isEmpty) {
      return Stream.value(const <BarCheckItem>[]);
    }

    final firestore = ref.watch(firebaseFirestoreProvider);
    final query = firestore
        .collection('gyms')
        .doc(gymId)
        .collection('barChecks')
        .doc(checkId)
        .collection('items');

    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map(BarCheckItem.fromSnapshot).toList(growable: false),
    );
  },
);

final currentGymBarIncomingProvider =
    StreamProvider<List<BarIncomingInvoiceSummary>>((ref) {
      final session = ref.watch(bootstrapControllerProvider).session;
      final gymId = session?.gymId;

      if (!_canManageBarData(session)) {
        return Stream.value(const <BarIncomingInvoiceSummary>[]);
      }

      final firestore = ref.watch(firebaseFirestoreProvider);
      final query = firestore
          .collection('gyms')
          .doc(gymId)
          .collection('barIncoming')
          .orderBy('createdAt', descending: true);

      return query.snapshots().map(
        (snapshot) => snapshot.docs
            .map(BarIncomingInvoiceSummary.fromSnapshot)
            .toList(growable: false),
      );
    });

final barSessionChecksProvider =
    StreamProvider.family<List<BarSessionCheckSummary>, String>((
      ref,
      sessionId,
    ) {
      final session = ref.watch(bootstrapControllerProvider).session;
      final gymId = session?.gymId;
      final normalizedSessionId = sessionId.trim();

      if (!_canReadBarData(session) || normalizedSessionId.isEmpty) {
        return Stream.value(const <BarSessionCheckSummary>[]);
      }

      final firestore = ref.watch(firebaseFirestoreProvider);
      final query = firestore
          .collection('gyms')
          .doc(gymId)
          .collection('barChecks')
          .where('sessionId', isEqualTo: normalizedSessionId);

      return query.snapshots().map((snapshot) {
        final checks =
            snapshot.docs
                .map(BarSessionCheckSummary.fromSnapshot)
                .where(
                  (check) =>
                      check.status == 'draft' ||
                      check.status == 'held' ||
                      check.status == 'paid' ||
                      check.status == 'refunded',
                )
                .toList(growable: false)
              ..sort((left, right) {
                final leftTime =
                    left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final rightTime =
                    right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return rightTime.compareTo(leftTime);
              });

        return checks;
      });
    });

bool _canReadBarData(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

bool _canManageBarData(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null && gymId.isNotEmpty && role == AllClubsRole.owner;
}
