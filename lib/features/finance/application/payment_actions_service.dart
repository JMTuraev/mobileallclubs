import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../core/utils/backend_action_error.dart';
import '../../../models/payment_amounts.dart';
import '../../clients/domain/client_detail_models.dart';
import '../domain/gym_transaction_summary.dart';

final paymentActionsServiceProvider = Provider<PaymentActionsService>((ref) {
  return PaymentActionsService(ref.watch(firebaseFunctionsProvider));
});

class PaymentActionsService {
  const PaymentActionsService(this._functions);

  final FirebaseFunctions _functions;

  Future<void> collectPayment({
    required String clientId,
    required ClientSubscriptionSummary subscription,
    required PaymentAmounts amounts,
    String? comment,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedSubscriptionId = subscription.id.trim();
    final entries = amounts
        .toJson()
        .entries
        .where((entry) => entry.value > 0)
        .toList(growable: false);

    if (normalizedClientId.isEmpty || normalizedSubscriptionId.isEmpty) {
      throw Exception('Missing payment context');
    }

    if (entries.isEmpty) {
      throw Exception('Enter a payment amount');
    }

    try {
      final callable = _functions.httpsCallable('createTransaction');
      for (final entry in entries) {
        await callable.call({
          'transaction': {
            'type': 'payment',
            'category': 'package',
            'clientId': normalizedClientId,
            'subscriptionId': normalizedSubscriptionId,
            'subscriptionStatus': _nullIfEmpty(subscription.status),
            'paymentMethod': entry.key,
            'amount': entry.value,
            'comment': _nullIfEmpty(comment),
          },
        });
      }
    } on FirebaseFunctionsException catch (error) {
      throw Exception(
        describeBackendActionError(error, fallback: 'Failed to collect payment'),
      );
    } catch (error) {
      throw Exception(
        describeBackendActionError(error, fallback: 'Failed to collect payment'),
      );
    }
  }

  Future<void> reversePayment({
    required String clientId,
    required GymTransactionSummary payment,
  }) async {
    final normalizedClientId = clientId.trim();
    final amount = payment.amount;

    if (normalizedClientId.isEmpty ||
        payment.id.trim().isEmpty ||
        amount == null) {
      throw Exception('Missing payment context');
    }

    await _createTransaction({
      'type': 'payment_reverse',
      'category': _nullIfEmpty(payment.category) ?? 'package',
      'clientId': normalizedClientId,
      'subscriptionId': _nullIfEmpty(payment.subscriptionId),
      'subscriptionStatus': _nullIfEmpty(payment.subscriptionStatus),
      'paymentMethod': _nullIfEmpty(payment.paymentMethod),
      'amount': -amount.abs(),
      'comment': _nullIfEmpty(payment.comment),
      'meta': {'originalTxId': payment.id},
    }, fallback: 'Failed to reverse payment');
  }

  Future<void> restorePayment({
    required String clientId,
    required GymTransactionSummary payment,
  }) async {
    final normalizedClientId = clientId.trim();
    final amount = payment.amount;

    if (normalizedClientId.isEmpty ||
        payment.id.trim().isEmpty ||
        amount == null) {
      throw Exception('Missing payment context');
    }

    await _createTransaction({
      'type': 'payment',
      'category': _nullIfEmpty(payment.category) ?? 'package',
      'clientId': normalizedClientId,
      'subscriptionId': _nullIfEmpty(payment.subscriptionId),
      'subscriptionStatus': _nullIfEmpty(payment.subscriptionStatus),
      'paymentMethod': _nullIfEmpty(payment.paymentMethod),
      'amount': amount.abs(),
      'comment': _nullIfEmpty(payment.comment),
      'meta': {'restoredFromTxId': payment.id},
    }, fallback: 'Failed to restore payment');
  }

  Future<void> deleteTransaction({required String transactionId}) async {
    final normalizedTransactionId = transactionId.trim();
    if (normalizedTransactionId.isEmpty) {
      throw Exception('Missing transaction context');
    }

    try {
      await _functions.httpsCallable('deleteTransaction').call({
        'transactionId': normalizedTransactionId,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(
        describeBackendActionError(
          error,
          fallback: 'Failed to delete transaction',
        ),
      );
    } catch (error) {
      throw Exception(
        describeBackendActionError(
          error,
          fallback: 'Failed to delete transaction',
        ),
      );
    }
  }

  Future<void> _createTransaction(
    Map<String, dynamic> transaction, {
    required String fallback,
  }) async {
    try {
      await _functions.httpsCallable('createTransaction').call({
        'transaction': transaction,
      });
    } on FirebaseFunctionsException catch (error) {
      throw Exception(describeBackendActionError(error, fallback: fallback));
    } catch (error) {
      throw Exception(describeBackendActionError(error, fallback: fallback));
    }
  }
}

String? _nullIfEmpty(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return value.trim();
}
