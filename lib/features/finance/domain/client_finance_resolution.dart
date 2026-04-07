import '../../clients/domain/client_detail_models.dart';
import 'gym_transaction_summary.dart';

class ClientFinanceResolution {
  const ClientFinanceResolution({
    required this.orderedSubscriptions,
    required this.selectedSubscription,
    required this.selectedPayments,
    required this.totalPaid,
    required this.totalOwed,
    required this.debt,
    required this.overpayment,
  });

  final List<ClientSubscriptionSummary> orderedSubscriptions;
  final ClientSubscriptionSummary? selectedSubscription;
  final List<GymTransactionSummary> selectedPayments;
  final num totalPaid;
  final num totalOwed;
  final num debt;
  final num overpayment;

  bool get canCollectPayment => selectedSubscription != null && debt > 0;
}

ClientFinanceResolution resolveClientFinanceResolution({
  required List<ClientSubscriptionSummary> subscriptions,
  required List<GymTransactionSummary> transactions,
}) {
  final orderedSubscriptions = orderClientSubscriptions(subscriptions);
  if (orderedSubscriptions.isEmpty) {
    return const ClientFinanceResolution(
      orderedSubscriptions: <ClientSubscriptionSummary>[],
      selectedSubscription: null,
      selectedPayments: <GymTransactionSummary>[],
      totalPaid: 0,
      totalOwed: 0,
      debt: 0,
      overpayment: 0,
    );
  }

  final selectedSubscription = orderedSubscriptions.first;
  final orderedTransactions = [...transactions]
    ..sort((left, right) {
      final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });

  final selectedPayments = orderedTransactions
      .where(
        (transaction) =>
            isPaymentTransaction(transaction) &&
            matchesFinanceSubscription(
              transaction,
              selectedSubscription,
              orderedSubscriptions,
            ),
      )
      .toList(growable: false);

  final totalPaid = selectedPayments.fold<num>(
    0,
    (sum, transaction) => sum + (transaction.amount ?? 0),
  );
  final totalOwed = selectedSubscription.packagePrice ?? 0;
  final debt = (totalOwed - totalPaid) > 0 ? totalOwed - totalPaid : 0;
  final overpayment = (totalPaid - totalOwed) > 0 ? totalPaid - totalOwed : 0;

  return ClientFinanceResolution(
    orderedSubscriptions: orderedSubscriptions,
    selectedSubscription: selectedSubscription,
    selectedPayments: selectedPayments,
    totalPaid: totalPaid,
    totalOwed: totalOwed,
    debt: debt,
    overpayment: overpayment,
  );
}

List<ClientSubscriptionSummary> orderClientSubscriptions(
  List<ClientSubscriptionSummary> subscriptions,
) {
  final ordered = [...subscriptions]
    ..sort((left, right) {
      final priorityComparison = left.sortPriority.compareTo(
        right.sortPriority,
      );
      if (priorityComparison != 0) {
        return priorityComparison;
      }

      final leftDate = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });

  return ordered;
}

bool isPaymentTransaction(GymTransactionSummary transaction) {
  return transaction.type == 'payment' || transaction.type == 'payment_reverse';
}

bool matchesFinanceSubscription(
  GymTransactionSummary transaction,
  ClientSubscriptionSummary subscription,
  List<ClientSubscriptionSummary> allSubscriptions,
) {
  if (transaction.subscriptionId == subscription.id) {
    return true;
  }

  if (transaction.subscriptionId != null &&
      transaction.subscriptionId!.isNotEmpty) {
    return false;
  }

  if (allSubscriptions.length == 1) {
    return true;
  }

  final transactionDate = transaction.createdAt;
  final start = subscription.startDate;
  final end = subscription.endDate;

  if (transactionDate == null || start == null || end == null) {
    return false;
  }

  return !transactionDate.isBefore(start) && !transactionDate.isAfter(end);
}
