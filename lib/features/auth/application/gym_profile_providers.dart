import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';

final currentGymProfileStreamProvider = StreamProvider<GymProfile?>((ref) {
  final session = ref.watch(bootstrapControllerProvider).session;
  final gymId = session?.gymId?.trim();

  if (gymId == null || gymId.isEmpty) {
    return Stream.value(session?.gym);
  }

  try {
    final firestore = ref.watch(firebaseFirestoreProvider);
    final gymDoc = firestore.collection('gyms').doc(gymId);

    return gymDoc.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return session?.gym;
      }

      return GymProfile.fromMap(gymId, data);
    });
  } catch (_) {
    return Stream.value(session?.gym);
  }
});
