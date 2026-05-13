import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../core/utils/backend_action_error.dart';

final packageActionsServiceProvider = Provider<PackageActionsService>((ref) {
  return PackageActionsService(ref.watch(firebaseFunctionsProvider));
});

class PackageUpsertRequest {
  const PackageUpsertRequest({
    required this.name,
    required this.price,
    required this.duration,
    required this.bonusDays,
    required this.startTime,
    required this.endTime,
    required this.freezeEnabled,
    required this.maxFreezeDays,
    required this.gender,
    required this.gradient,
    required this.description,
  });

  final String name;
  final num price;
  final int duration;
  final int bonusDays;
  final String? startTime;
  final String? endTime;
  final bool freezeEnabled;
  final int maxFreezeDays;
  final String gender;
  final String gradient;
  final String description;

  int get visitLimit => duration + bonusDays;

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'duration': duration,
      'bonusDays': bonusDays,
      'price': price,
      'visitLimit': visitLimit,
      'type': 'fixed',
      'isUnlimited': false,
      'startTime': _nullIfEmpty(startTime),
      'endTime': _nullIfEmpty(endTime),
      'freezeEnabled': freezeEnabled,
      'maxFreezeDays': freezeEnabled ? maxFreezeDays : 0,
      'gender': gender.trim().isEmpty ? 'all' : gender.trim(),
      'gradient': gradient.trim().isEmpty
          ? 'from-indigo-500 to-indigo-700'
          : gradient.trim(),
      'description': description.trim(),
    };
  }
}

class PackageActionResult {
  const PackageActionResult({required this.success, this.packageId});

  final bool success;
  final String? packageId;
}

class PackageActionsService {
  const PackageActionsService(this._functions);

  final FirebaseFunctions _functions;

  Future<PackageActionResult> createPackage({
    required PackageUpsertRequest request,
  }) async {
    _validate(request);

    try {
      final result = await _functions.httpsCallable('createPackage').call({
        'packageData': request.toJson(),
      });
      return _resolveResult(result.data, fallback: 'Failed to create package');
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to create package'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<PackageActionResult> updatePackage({
    required String packageId,
    required PackageUpsertRequest request,
  }) async {
    final normalizedPackageId = packageId.trim();
    if (normalizedPackageId.isEmpty) {
      throw Exception('Missing packageId');
    }

    _validate(request);

    try {
      final result = await _functions.httpsCallable('updatePackage').call({
        'packageId': normalizedPackageId,
        'packageData': request.toJson(),
      });
      return _resolveResult(
        result.data,
        fallback: 'Failed to update package',
        packageId: normalizedPackageId,
      );
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to update package'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> deletePackage({required String packageId}) async {
    final normalizedPackageId = packageId.trim();
    if (normalizedPackageId.isEmpty) {
      throw Exception('Missing packageId');
    }

    try {
      final result = await _functions.httpsCallable('deletePackage').call({
        'packageId': normalizedPackageId,
      });
      final data = result.data;

      if (data is Map && data['success'] == false) {
        throw Exception(
          data['error']?.toString() ?? 'Failed to delete package',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to delete package'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  void _validate(PackageUpsertRequest request) {
    if (request.name.trim().isEmpty) {
      throw Exception('Package name is required');
    }

    if (request.price <= 0) {
      throw Exception('Price must be greater than 0');
    }

    if (request.duration <= 0) {
      throw Exception('Duration must be greater than 0');
    }
  }

  PackageActionResult _resolveResult(
    dynamic data, {
    required String fallback,
    String? packageId,
  }) {
    if (data is! Map) {
      return PackageActionResult(success: true, packageId: packageId);
    }

    final success = data['success'] != false;
    final resolvedPackageId =
        data['packageId']?.toString() ?? data['id']?.toString() ?? packageId;

    if (!success) {
      throw Exception(data['error']?.toString() ?? fallback);
    }

    return PackageActionResult(success: true, packageId: resolvedPackageId);
  }
}

String? _nullIfEmpty(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value.trim();
}

String _firebaseMessage(FirebaseFunctionsException error, String fallback) {
  return describeBackendActionError(error, fallback: fallback);
}

String _cleanError(Object error) {
  return describeBackendActionError(error, fallback: 'Unexpected error');
}
