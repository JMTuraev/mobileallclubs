import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/backend_action_error.dart';

class CreateGymRequest {
  const CreateGymRequest({
    required this.name,
    required this.city,
    required this.phone,
    required this.firstName,
    required this.lastName,
  });

  final String name;
  final String city;
  final String phone;
  final String firstName;
  final String lastName;

  Map<String, dynamic> toGymData() {
    return {
      'name': name,
      'city': city,
      'phone': phone,
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}

class CreateGymResult {
  const CreateGymResult({required this.success, this.gymId});

  final bool success;
  final String? gymId;
}

class ClearOnboardingLockResult {
  const ClearOnboardingLockResult({required this.success, required this.uid});

  final bool success;
  final String uid;
}

Future<CreateGymResult> createGymAndUser({
  required User firebaseUser,
  required FirebaseFunctions functions,
  required CreateGymRequest request,
}) async {
  final uid = firebaseUser.uid;
  final email = firebaseUser.email;

  if (uid.isEmpty || email == null || email.trim().isEmpty) {
    throw Exception('Invalid Firebase user');
  }

  if (request.name.trim().isEmpty) {
    throw Exception('Gym name is required');
  }

  if (request.city.trim().isEmpty) {
    throw Exception('City is required');
  }

  try {
    await firebaseUser.getIdToken(true);

    final result = await functions.httpsCallable('createGymAndUser').call({
      'gymData': request.toGymData(),
    });

    await firebaseUser.getIdToken(true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await firebaseUser.getIdToken(true);

    final data = result.data;
    if (data is Map) {
      return CreateGymResult(success: true, gymId: data['gymId']?.toString());
    }

    return const CreateGymResult(success: true);
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      describeBackendActionError(error, fallback: 'Unknown onboarding error'),
    );
  } catch (error) {
    throw Exception(
      describeBackendActionError(error, fallback: 'Unknown onboarding error'),
    );
  }
}

Future<ClearOnboardingLockResult> clearOnboardingLock({
  required FirebaseFunctions functions,
  required String uid,
}) async {
  final normalizedUid = uid.trim();
  if (normalizedUid.isEmpty) {
    throw Exception('Missing uid');
  }

  try {
    final result = await functions.httpsCallable('clearOnboardingLock').call({
      'uid': normalizedUid,
    });

    final data = result.data;
    if (data is Map) {
      return ClearOnboardingLockResult(
        success: data['success'] == true,
        uid: data['uid']?.toString() ?? normalizedUid,
      );
    }

    return ClearOnboardingLockResult(success: true, uid: normalizedUid);
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      describeBackendActionError(
        error,
        fallback: 'Failed to clear onboarding lock',
      ),
    );
  } catch (error) {
    throw Exception(
      describeBackendActionError(
        error,
        fallback: 'Failed to clear onboarding lock',
      ),
    );
  }
}
