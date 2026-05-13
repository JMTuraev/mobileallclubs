import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../core/utils/backend_action_error.dart';
import '../../../models/payment_amounts.dart';

final subscriptionSaleServiceProvider = Provider<SubscriptionSaleService>((
  ref,
) {
  return SubscriptionSaleService(ref.watch(firebaseFunctionsProvider));
});

class SubscriptionSaleService {
  const SubscriptionSaleService(this._functions);

  final FirebaseFunctions _functions;

  Future<SubscriptionSaleResult> createSubscription({
    required String clientId,
    required String packageId,
    required String startDate,
    required PaymentAmounts amounts,
    String? comment,
    String? replaceId,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedPackageId = packageId.trim();
    final normalizedStartDate = startDate.trim();

    if (normalizedClientId.isEmpty) {
      throw Exception('Missing clientId');
    }

    if (normalizedPackageId.isEmpty) {
      throw Exception('Missing packageId');
    }

    if (normalizedStartDate.isEmpty) {
      throw Exception('Missing startDate');
    }

    if (!amounts.isBalanced) {
      throw Exception('Payment amounts must fully cover the package total.');
    }

    try {
      final result = await _functions.httpsCallable('createSubscription').call({
        'clientId': normalizedClientId,
        'packageId': normalizedPackageId,
        'startDate': normalizedStartDate,
        'amounts': amounts.toJson(),
        'comment': _nullIfEmpty(comment),
        'replaceId': _nullIfEmpty(replaceId),
      });
      final data = result.data;

      if (data is! Map) {
        return const SubscriptionSaleResult(success: true);
      }

      final success = data['success'] != false;
      final subscriptionId =
          data['subscriptionId']?.toString() ?? data['id']?.toString();

      if (!success) {
        throw Exception(
          data['error']?.toString() ?? 'Failed to create subscription',
        );
      }

      return SubscriptionSaleResult(
        success: true,
        subscriptionId: subscriptionId,
      );
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to create subscription'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> updateSubscriptionStartDate({
    required String subscriptionId,
    required String newStartDate,
  }) async {
    final normalizedSubscriptionId = subscriptionId.trim();
    final normalizedStartDate = newStartDate.trim();

    if (normalizedSubscriptionId.isEmpty) {
      throw Exception('Missing subscriptionId');
    }

    if (normalizedStartDate.isEmpty) {
      throw Exception('Missing newStartDate');
    }

    try {
      final result = await _functions
          .httpsCallable('updateSubscriptionStartDate')
          .call({
            'subscriptionId': normalizedSubscriptionId,
            'newStartDate': normalizedStartDate,
          });
      final data = result.data;

      if (data is Map && data['success'] == false) {
        throw Exception(
          data['error']?.toString() ??
              'Failed to update subscription start date',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      throw Exception(
        _firebaseMessage(error, 'Failed to update subscription start date'),
      );
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> updateSubscription({
    required String subscriptionId,
    required Map<String, dynamic> updateData,
  }) async {
    final normalizedSubscriptionId = subscriptionId.trim();

    if (normalizedSubscriptionId.isEmpty) {
      throw Exception('Missing subscriptionId');
    }

    if (updateData.isEmpty) {
      throw Exception('Missing updateData');
    }

    try {
      final result = await _functions.httpsCallable('updateSubscription').call({
        'subscriptionId': normalizedSubscriptionId,
        'updateData': updateData,
      });
      final data = result.data;

      if (data is Map && data['success'] == false) {
        throw Exception(
          data['error']?.toString() ?? 'Failed to update subscription',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to update subscription'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> activateSubscription({required String subscriptionId}) {
    return updateSubscription(
      subscriptionId: subscriptionId,
      updateData: <String, dynamic>{
        'status': 'active',
        'activatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deactivateSubscription({required String subscriptionId}) {
    return updateSubscription(
      subscriptionId: subscriptionId,
      updateData: <String, dynamic>{
        'status': 'inactive',
        'deactivatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> cancelSubscription({required String subscriptionId}) {
    return updateSubscription(
      subscriptionId: subscriptionId,
      updateData: <String, dynamic>{
        'status': 'cancelled',
        'deletedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }
}

class SubscriptionSaleResult {
  const SubscriptionSaleResult({required this.success, this.subscriptionId});

  final bool success;
  final String? subscriptionId;
}

String _firebaseMessage(FirebaseFunctionsException error, String fallback) {
  return describeBackendActionError(error, fallback: fallback);
}

String _cleanError(Object error) {
  return describeBackendActionError(error, fallback: 'Unexpected error');
}

String? _nullIfEmpty(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value.trim();
}
