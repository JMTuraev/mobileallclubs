import '../../clients/domain/client_detail_models.dart';
import '../../clients/domain/client_summary.dart';
import 'gym_transaction_summary.dart';

class FinanceClientOverviewItem {
  const FinanceClientOverviewItem({
    required this.clientId,
    required this.clientName,
    required this.totalRevenue,
    required this.debt,
    required this.lastActivityAt,
  });

  final String clientId;
  final String clientName;
  final num totalRevenue;
  final num debt;
  final DateTime? lastActivityAt;
}

class FinancePageSnapshot {
  const FinancePageSnapshot({
    required this.dateFilteredTransactions,
    required this.transactions,
    required this.overviews,
    required this.fallbackNamesByClientId,
    required this.selectedClientId,
    required this.selectedClientName,
    required this.totalRevenue,
    required this.totalDebt,
    required this.filteredTotal,
  });

  final List<GymTransactionSummary> dateFilteredTransactions;
  final List<GymTransactionSummary> transactions;
  final List<FinanceClientOverviewItem> overviews;
  final Map<String, String> fallbackNamesByClientId;
  final String? selectedClientId;
  final String? selectedClientName;
  final num totalRevenue;
  final num totalDebt;
  final num filteredTotal;
}

FinancePageSnapshot buildFinancePageSnapshot({
  required List<GymTransactionSummary> transactions,
  required List<ClientSubscriptionSummary> subscriptions,
  required Map<String, GymClientSummary> clientsById,
  required DateTime? from,
  required DateTime? to,
  String? selectedClientId,
}) {
  final activeTransactions = transactions
      .where((transaction) => !_isReplacedSubscriptionTransaction(transaction))
      .toList(growable: false);
  final dateFilteredTransactions = _filterTransactionsByDate(
    activeTransactions,
    from: from,
    to: to,
  );
  final fallbackNamesByClientId = buildFinanceFallbackClientNames(
    subscriptions,
  );
  final overviews = _buildClientOverviews(
    transactions: dateFilteredTransactions,
    clientsById: clientsById,
    fallbackNamesByClientId: fallbackNamesByClientId,
  );
  final subscriptionsById = <String, ClientSubscriptionSummary>{
    for (final subscription in subscriptions) subscription.id: subscription,
  };
  final normalizedSelectedClientId = _normalizeValue(selectedClientId);
  final visibleTransactions = dateFilteredTransactions
      .where(
        (transaction) => isFinanceTransactionVisibleInTable(
          transaction,
          subscriptionsById: subscriptionsById,
          clientIdFilter: normalizedSelectedClientId,
        ),
      )
      .toList(growable: false);
  final selectedClientName = normalizedSelectedClientId == null
      ? null
      : resolveFinanceClientName(
          clientId: normalizedSelectedClientId,
          clientsById: clientsById,
          fallbackNamesByClientId: fallbackNamesByClientId,
        );
  final totalRevenue = overviews.fold<num>(
    0,
    (sum, item) => sum + item.totalRevenue,
  );
  final totalDebt = overviews.fold<num>(0, (sum, item) => sum + item.debt);
  final filteredTotal = visibleTransactions.fold<num>(
    0,
    (sum, transaction) => sum + (transaction.amount ?? 0),
  );

  return FinancePageSnapshot(
    dateFilteredTransactions: dateFilteredTransactions,
    transactions: visibleTransactions,
    overviews: overviews,
    fallbackNamesByClientId: fallbackNamesByClientId,
    selectedClientId: normalizedSelectedClientId,
    selectedClientName: selectedClientName,
    totalRevenue: totalRevenue,
    totalDebt: totalDebt,
    filteredTotal: filteredTotal,
  );
}

Map<String, String> buildFinanceFallbackClientNames(
  List<ClientSubscriptionSummary> subscriptions,
) {
  final orderedSubscriptions = [...subscriptions]..sort(_compareSubscriptions);
  final fallbackNamesByClientId = <String, String>{};

  for (final subscription in orderedSubscriptions) {
    final clientId = _normalizeValue(subscription.clientId);
    final clientName = _normalizeValue(subscription.clientName);
    if (clientId == null ||
        clientName == null ||
        fallbackNamesByClientId.containsKey(clientId)) {
      continue;
    }

    fallbackNamesByClientId[clientId] = clientName;
  }

  return fallbackNamesByClientId;
}

String resolveFinanceClientName({
  required String clientId,
  required Map<String, GymClientSummary> clientsById,
  required Map<String, String> fallbackNamesByClientId,
}) {
  final client = clientsById[clientId];
  if (client != null) {
    return client.fullName;
  }

  final fallbackName = fallbackNamesByClientId[clientId];
  if (fallbackName != null && fallbackName.isNotEmpty) {
    return fallbackName;
  }

  return 'Unknown client';
}

String resolveFinanceClientLabel({
  required GymTransactionSummary transaction,
  required Map<String, GymClientSummary> clientsById,
  required Map<String, String> fallbackNamesByClientId,
}) {
  final clientId = _normalizeValue(transaction.clientId);
  if (clientId == null) {
    return 'System';
  }

  return resolveFinanceClientName(
    clientId: clientId,
    clientsById: clientsById,
    fallbackNamesByClientId: fallbackNamesByClientId,
  );
}

bool isFinanceTransactionVisibleInTable(
  GymTransactionSummary transaction, {
  required Map<String, ClientSubscriptionSummary> subscriptionsById,
  String? clientIdFilter,
}) {
  final normalizedStatus = _normalizeValue(transaction.status)?.toLowerCase();
  if (normalizedStatus == 'cancelled') {
    return false;
  }

  final normalizedCategory = _normalizeValue(
    transaction.category,
  )?.toLowerCase();
  final normalizedType = _normalizeValue(transaction.type)?.toLowerCase();
  final isPackageTransaction =
      normalizedCategory == 'package' ||
      (normalizedType == 'payment' &&
          _normalizeValue(transaction.subscriptionId) != null);

  if (isPackageTransaction) {
    final subscriptionId = _normalizeValue(transaction.subscriptionId);
    if (subscriptionId == null) {
      return false;
    }

    final subscription = subscriptionsById[subscriptionId];
    if (subscription == null) {
      return false;
    }

    if ((_normalizeValue(subscription.status)?.toLowerCase()) != 'active') {
      return false;
    }
  }

  if (clientIdFilter == null) {
    return true;
  }

  return _normalizeValue(transaction.clientId) == clientIdFilter;
}

List<FinanceClientOverviewItem> _buildClientOverviews({
  required List<GymTransactionSummary> transactions,
  required Map<String, GymClientSummary> clientsById,
  required Map<String, String> fallbackNamesByClientId,
}) {
  final overviewByClientId = <String, _FinanceClientAggregate>{};

  for (final transaction in transactions) {
    final clientId = _normalizeValue(transaction.clientId);
    if (clientId == null) {
      continue;
    }

    final aggregate = overviewByClientId.putIfAbsent(
      clientId,
      () => _FinanceClientAggregate(
        clientName: resolveFinanceClientName(
          clientId: clientId,
          clientsById: clientsById,
          fallbackNamesByClientId: fallbackNamesByClientId,
        ),
      ),
    );
    final amount = transaction.amount ?? 0;
    aggregate.totalRevenue += amount;

    if ((_normalizeValue(transaction.paymentMethod)?.toLowerCase()) == 'debt') {
      aggregate.debt += amount;
    }

    final createdAt = transaction.createdAt;
    if (createdAt != null &&
        (aggregate.lastActivityAt == null ||
            createdAt.isAfter(aggregate.lastActivityAt!))) {
      aggregate.lastActivityAt = createdAt;
    }
  }

  return overviewByClientId.entries
      .map(
        (entry) => FinanceClientOverviewItem(
          clientId: entry.key,
          clientName: entry.value.clientName,
          totalRevenue: entry.value.totalRevenue,
          debt: entry.value.debt,
          lastActivityAt: entry.value.lastActivityAt,
        ),
      )
      .toList(growable: false);
}

List<GymTransactionSummary> _filterTransactionsByDate(
  List<GymTransactionSummary> transactions, {
  required DateTime? from,
  required DateTime? to,
}) {
  if (from == null && to == null) {
    return transactions;
  }

  final start = from == null ? null : _startOfDay(from);
  final end = to == null ? null : _endOfDay(to);

  return transactions
      .where((transaction) {
        final createdAt = transaction.createdAt?.toLocal();
        if (createdAt == null) {
          return false;
        }

        if (start != null && createdAt.isBefore(start)) {
          return false;
        }

        if (end != null && createdAt.isAfter(end)) {
          return false;
        }

        return true;
      })
      .toList(growable: false);
}

bool _isReplacedSubscriptionTransaction(GymTransactionSummary transaction) {
  return _normalizeValue(transaction.subscriptionStatus)?.toLowerCase() ==
      'replaced';
}

int _compareSubscriptions(
  ClientSubscriptionSummary first,
  ClientSubscriptionSummary second,
) {
  final priorityCompare = first.sortPriority.compareTo(second.sortPriority);
  if (priorityCompare != 0) {
    return priorityCompare;
  }

  final firstDate =
      first.startDate ??
      first.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
  final secondDate =
      second.startDate ??
      second.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
  return secondDate.compareTo(firstDate);
}

DateTime _startOfDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _endOfDay(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day, 23, 59, 59, 999);
}

String? _normalizeValue(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}

class _FinanceClientAggregate {
  _FinanceClientAggregate({required this.clientName});

  final String clientName;
  num totalRevenue = 0;
  num debt = 0;
  DateTime? lastActivityAt;
}
