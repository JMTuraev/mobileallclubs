import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../domain/gym_package_summary.dart';

final currentGymPackagesProvider = StreamProvider<List<GymPackageSummary>>((
  ref,
) {
  final session = ref.watch(bootstrapControllerProvider).session;
  final gymId = session?.gymId;

  if (!_canReadPackages(session) || gymId == null || gymId.isEmpty) {
    return Stream.value(const <GymPackageSummary>[]);
  }

  final firestore = ref.watch(firebaseFirestoreProvider);
  final packagesRef = firestore
      .collection('gyms')
      .doc(gymId)
      .collection('packages');
  final indexedQuery = packagesRef
      .where('isArchived', isEqualTo: false)
      .orderBy('createdAt', descending: true);
  final fallbackQuery = packagesRef.where('isArchived', isEqualTo: false);

  return Stream.multi((controller) {
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? indexedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? fallbackSub;
    var usingFallback = false;

    void emitPackages(QuerySnapshot<Map<String, dynamic>> snapshot) {
      final packages =
          snapshot.docs
              .map(GymPackageSummary.fromSnapshot)
              .where((package) => package.isArchived == false)
              .toList(growable: false)
            ..sort((left, right) {
              final leftDate =
                  left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              final rightDate =
                  right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
              return rightDate.compareTo(leftDate);
            });
      controller.add(packages);
    }

    void attachFallback() {
      if (usingFallback) {
        return;
      }

      usingFallback = true;
      fallbackSub = fallbackQuery.snapshots().listen(
        emitPackages,
        onError: controller.addError,
      );
    }

    indexedSub = indexedQuery.snapshots().listen(
      emitPackages,
      onError: (error, stackTrace) {
        if (_isIndexError(error)) {
          attachFallback();
          return;
        }

        controller.addError(error, stackTrace);
      },
    );

    controller.onCancel = () async {
      await indexedSub?.cancel();
      await fallbackSub?.cancel();
    };
  });
});

bool _canReadPackages(ResolvedAuthSession? session) {
  final role = session?.role ?? AllClubsRole.unknown;
  final gymId = session?.gymId;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

bool _isIndexError(Object error) {
  if (error is FirebaseException) {
    return error.code == 'failed-precondition' ||
        (error.message?.toLowerCase().contains('requires an index') ?? false);
  }

  final message = error.toString().toLowerCase();
  return message.contains('requires an index');
}
