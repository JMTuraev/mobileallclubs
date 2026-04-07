import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/super_admin_config.dart';
import '../../models/auth_bootstrap_models.dart';
import 'firebase_clients.dart';

final resolvedAuthSessionStreamProvider = StreamProvider<ResolvedAuthSession?>((
  ref,
) async* {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firebaseFirestoreProvider);
  final functions = ref.watch(firebaseFunctionsProvider);

  await for (final firebaseUser in auth.userChanges()) {
    if (firebaseUser == null) {
      yield null;
      continue;
    }

    yield await _resolveCurrentSession(
      firestore: firestore,
      functions: functions,
      firebaseUser: firebaseUser,
    );
  }
});

Future<ResolvedAuthSession> _resolveCurrentSession({
  required FirebaseFirestore firestore,
  required FirebaseFunctions functions,
  required User firebaseUser,
}) async {
  final authUser = AuthenticatedUserSnapshot.fromFirebaseUser(firebaseUser);
  final usersCollection = firestore.collection('users');
  var userSnapshot = await usersCollection.doc(authUser.uid).get();

  if (_shouldSyncSuperAdmin(authUser, userSnapshot)) {
    userSnapshot = await _syncSuperAdminProfile(
      usersCollection: usersCollection,
      functions: functions,
      firebaseUser: firebaseUser,
      currentSnapshot: userSnapshot,
    );
  }

  if (!userSnapshot.exists) {
    if (isSuperAdminEmail(authUser.email)) {
      return _buildFallbackSuperAdminSession(authUser);
    }

    return ResolvedAuthSession(authUser: authUser);
  }

  final userProfile = GlobalUserProfile.fromMap(
    authUser.uid,
    userSnapshot.data()!,
  );

  if (userProfile.role == AllClubsRole.superAdmin) {
    return ResolvedAuthSession(authUser: authUser, userProfile: userProfile);
  }

  final gymId = userProfile.gymId;
  if (gymId == null || gymId.isEmpty) {
    return ResolvedAuthSession(authUser: authUser, userProfile: userProfile);
  }

  final membershipSnapshot = await firestore
      .collection('gyms')
      .doc(gymId)
      .collection('users')
      .doc(authUser.uid)
      .get();

  final gymSnapshot = await firestore.collection('gyms').doc(gymId).get();
  final gymMembership = membershipSnapshot.exists
      ? GymMembershipProfile.fromMap(
          gymId,
          authUser.uid,
          membershipSnapshot.data()!,
        )
      : null;
  final gym = gymSnapshot.exists
      ? GymProfile.fromMap(gymId, gymSnapshot.data()!)
      : null;

  return ResolvedAuthSession(
    authUser: authUser,
    userProfile: userProfile,
    gymMembership: gymMembership,
    gym: gym,
  );
}

bool _shouldSyncSuperAdmin(
  AuthenticatedUserSnapshot authUser,
  DocumentSnapshot<Map<String, dynamic>> userSnapshot,
) {
  if (!isSuperAdminEmail(authUser.email)) {
    return false;
  }

  if (!userSnapshot.exists) {
    return true;
  }

  final roleValue = userSnapshot.data()?['role']?.toString();
  return roleValue != AllClubsRole.superAdmin.wireValue;
}

Future<DocumentSnapshot<Map<String, dynamic>>> _syncSuperAdminProfile({
  required CollectionReference<Map<String, dynamic>> usersCollection,
  required FirebaseFunctions functions,
  required User firebaseUser,
  required DocumentSnapshot<Map<String, dynamic>> currentSnapshot,
}) async {
  try {
    await functions.httpsCallable('syncSuperAdminAccess').call();
    await firebaseUser.getIdToken(true);
    return await usersCollection.doc(firebaseUser.uid).get();
  } catch (_) {
    return currentSnapshot;
  }
}

ResolvedAuthSession _buildFallbackSuperAdminSession(
  AuthenticatedUserSnapshot authUser,
) {
  return ResolvedAuthSession(
    authUser: authUser,
    userProfile: GlobalUserProfile(
      uid: authUser.uid,
      email: authUser.email,
      roleValue: AllClubsRole.superAdmin.wireValue,
      isActive: true,
    ),
  );
}
