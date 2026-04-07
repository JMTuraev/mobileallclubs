import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import 'create_staff_service.dart';
import '../domain/gym_staff_summary.dart';

final currentGymStaffStreamProvider = StreamProvider<List<GymStaffSummary>>((
  ref,
) {
  final session = ref.watch(bootstrapControllerProvider).session;

  if (!_canReadStaff(session)) {
    return Stream.value(const <GymStaffSummary>[]);
  }

  final firestore = ref.watch(firebaseFirestoreProvider);
  final query = firestore
      .collection('gyms')
      .doc(session!.gymId)
      .collection('users');

  return query.snapshots().map((snapshot) {
    final staff = snapshot.docs
        .map(GymStaffSummary.fromSnapshot)
        .where((member) => member.isStaffRole)
        .toList(growable: false)
      ..sort((left, right) {
        final rightValue = right.createdAtEpochMillis ?? 0;
        final leftValue = left.createdAtEpochMillis ?? 0;
        return rightValue.compareTo(leftValue);
      });

    return staff;
  });
});

final activeStaffIdsProvider = FutureProvider<Set<String>>((ref) async {
  final session = ref.watch(bootstrapControllerProvider).session;

  if (!_canReadStaff(session)) {
    return const <String>{};
  }

  final functions = ref.watch(firebaseFunctionsProvider);
  final activeStaff = await getActiveStaff(functions: functions);

  return activeStaff.map((member) => member.id).toSet();
});

bool _canReadStaff(ResolvedAuthSession? session) {
  if (session == null) {
    return false;
  }

  final gymId = session.gymId;

  return gymId != null &&
      gymId.isNotEmpty &&
      session.role == AllClubsRole.owner;
}
