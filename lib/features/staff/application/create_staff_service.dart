import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/utils/backend_action_error.dart';
import '../domain/gym_staff_summary.dart';

class CreateStaffRequest {
  const CreateStaffRequest({
    required this.email,
    required this.password,
    required this.fullName,
    required this.phone,
  });

  final String email;
  final String password;
  final String fullName;
  final String phone;

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim().toLowerCase(),
      'password': password,
      'fullName': fullName.trim(),
      'phone': phone.trim(),
    };
  }
}

class CreateStaffResult {
  const CreateStaffResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class StaffActionResult {
  const StaffActionResult({
    required this.success,
    this.message,
    this.userId,
    this.isActive,
  });

  final bool success;
  final String? message;
  final String? userId;
  final bool? isActive;
}

class UpdateStaffRequest {
  const UpdateStaffRequest({
    required this.userId,
    this.fullName,
    this.phone,
  });

  final String userId;
  final String? fullName;
  final String? phone;

  Map<String, dynamic> toJson() {
    final updates = <String, dynamic>{};

    if (fullName != null) {
      updates['fullName'] = fullName!.trim();
    }

    if (phone != null) {
      updates['phone'] = phone!.trim();
    }

    return {'userId': userId.trim(), 'updates': updates};
  }
}

Future<CreateStaffResult> createStaff({
  required FirebaseFunctions functions,
  required CreateStaffRequest request,
}) async {
  final email = request.email.trim().toLowerCase();
  final password = request.password;

  if (email.isEmpty || !email.contains('@')) {
    throw Exception('Invalid email format');
  }

  if (password.length < 6) {
    throw Exception('Password must be at least 6 characters');
  }

  if (request.phone.trim().isNotEmpty &&
      !RegExp(r'^[+]?\d{7,}$').hasMatch(request.phone.trim())) {
    throw Exception('Invalid phone number');
  }

  try {
    final result = await functions
        .httpsCallable('createStaff')
        .call(request.toJson());
    final data = result.data;

    if (data is Map && data['success'] == false) {
      throw Exception(data['error']?.toString() ?? 'Failed to create staff');
    }

    return CreateStaffResult(
      success: true,
      message: data is Map ? data['message']?.toString() : null,
    );
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      describeBackendActionError(error, fallback: 'Failed to create staff'),
    );
  } catch (error) {
    throw Exception(
      describeBackendActionError(error, fallback: 'Failed to create staff'),
    );
  }
}

Future<StaffActionResult> setStaffActiveState({
  required FirebaseFunctions functions,
  required String userId,
  required bool isActive,
}) async {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    throw Exception('User ID is required');
  }

  try {
    final result = await functions.httpsCallable('deactivateStaff').call({
      'userId': normalizedUserId,
      'isActive': isActive,
    });
    final data = result.data;

    if (data is Map && data['success'] == false) {
      throw Exception(
        data['error']?.toString() ??
            (isActive
                ? 'Failed to reactivate staff member'
                : 'Failed to deactivate staff member'),
      );
    }

    return StaffActionResult(
      success: true,
      message: data is Map ? data['message']?.toString() : null,
      userId: data is Map ? data['userId']?.toString() : normalizedUserId,
      isActive: data is Map ? data['isActive'] as bool? : isActive,
    );
  } on FirebaseFunctionsException catch (error) {
    final fallback = isActive
        ? 'Failed to reactivate staff member'
        : 'Failed to deactivate staff member';
    throw Exception(describeBackendActionError(error, fallback: fallback));
  } catch (error) {
    throw Exception(
      describeBackendActionError(
        error,
        fallback: isActive
            ? 'Failed to reactivate staff member'
            : 'Failed to deactivate staff member',
      ),
    );
  }
}

Future<StaffActionResult> removeStaffMember({
  required FirebaseFunctions functions,
  required String userId,
}) async {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty) {
    throw Exception('User ID is required');
  }

  try {
    final result = await functions.httpsCallable('removeStaff').call({
      'userId': normalizedUserId,
    });
    final data = result.data;

    if (data is Map && data['success'] == false) {
      throw Exception(data['error']?.toString() ?? 'Failed to remove staff');
    }

    return StaffActionResult(
      success: true,
      message: data is Map ? data['message']?.toString() : null,
      userId: data is Map ? data['userId']?.toString() : normalizedUserId,
    );
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      describeBackendActionError(error, fallback: 'Failed to remove staff'),
    );
  } catch (error) {
    throw Exception(
      describeBackendActionError(error, fallback: 'Failed to remove staff'),
    );
  }
}

Future<StaffActionResult> updateStaffMember({
  required FirebaseFunctions functions,
  required UpdateStaffRequest request,
}) async {
  final normalizedUserId = request.userId.trim();
  if (normalizedUserId.isEmpty) {
    throw Exception('User ID is required');
  }

  final normalizedPhone = request.phone?.trim();
  if (normalizedPhone != null &&
      normalizedPhone.isNotEmpty &&
      !RegExp(r'^[+]?\d{7,}$').hasMatch(normalizedPhone)) {
    throw Exception('Invalid phone number');
  }

  try {
    final result = await functions
        .httpsCallable('updateStaff')
        .call(request.toJson());
    final data = result.data;

    if (data is Map && data['success'] == false) {
      throw Exception(data['error']?.toString() ?? 'Failed to update staff');
    }

    return StaffActionResult(
      success: true,
      message: data is Map ? data['message']?.toString() : null,
      userId: data is Map ? data['userId']?.toString() : normalizedUserId,
    );
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      describeBackendActionError(error, fallback: 'Failed to update staff'),
    );
  } catch (error) {
    throw Exception(
      describeBackendActionError(error, fallback: 'Failed to update staff'),
    );
  }
}

Future<List<GymStaffSummary>> getActiveStaff({
  required FirebaseFunctions functions,
}) async {
  try {
    final result = await functions.httpsCallable('getActiveStaff').call({});
    final data = result.data;

    if (data is! List) {
      return const <GymStaffSummary>[];
    }

    return data
        .whereType<Map>()
        .map(
          (item) => GymStaffSummary.fromMap(
            item['id']?.toString() ?? item['uid']?.toString() ?? '',
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((member) => member.id.isNotEmpty)
        .toList(growable: false);
  } on FirebaseFunctionsException catch (_) {
    return const <GymStaffSummary>[];
  } catch (_) {
    return const <GymStaffSummary>[];
  }
}
