import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/payment_actions_service.dart';
import '../application/transaction_providers.dart';
import '../domain/gym_transaction_summary.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  String? _statusMessage;
  bool _statusIsError = false;
  final Set<String> _busyTransactionIds = <String>{};

  void _setStatus(String message, {required bool isError}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _deleteTransaction(GymTransactionSummary transaction) async {
    if (_busyTransactionIds.contains(transaction.id)) {
      return;
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text(
          'This uses the exact deleteTransaction callable for ${transaction.id}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldProceed != true) {
      return;
    }

    setState(() {
      _busyTransactionIds.add(transaction.id);
    });

    try {
      await ref
          .read(paymentActionsServiceProvider)
          .deleteTransaction(transactionId: transaction.id);

      if (!mounted) {
        return;
      }

      _setStatus('Transaction deleted.', isError: false);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyTransactionIds.remove(transaction.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final transactionsAsync = ref.watch(currentGymTransactionsProvider);
    final theme = Theme.of(context);
    final canDeleteTransactions = session?.role == AllClubsRole.owner;

    return AppShellBody(
      child: !_canAccessFinance(session)
          ? _FinanceAccessBlocked(onBack: () => context.go(AppRoutes.app))
          : transactionsAsync.when(
              loading: () => _FinanceLoadingCard(gymName: session?.gym?.name),
              error: (error, stackTrace) =>
                  _FinanceErrorCard(message: error.toString()),
              data: (transactions) {
                final totalTracked = transactions.fold<num>(
                  0,
                  (sum, transaction) => sum + (transaction.amount ?? 0),
                );
                final paymentCount = transactions
                    .where((transaction) => transaction.type == 'payment')
                    .length;
                final recentTransactions = transactions.take(24).toList();

                return ListView(
                  children: [
                    if (_statusMessage != null) ...[
                      _FinanceStatusCard(
                        title: _statusIsError ? 'Finance action failed' : 'Finance',
                        message: _statusMessage!,
                        isError: _statusIsError,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session?.gym?.name ?? 'Finance',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Live finance overview from gyms/${session?.gymId}/transactions and gyms/${session?.gymId}/financeTransactions.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _MetricChip(
                                  icon: Icons.receipt_long_rounded,
                                  label: '${transactions.length} entries',
                                ),
                                _MetricChip(
                                  icon: Icons.payments_rounded,
                                  label: '$paymentCount payments',
                                ),
                                _MetricChip(
                                  icon: Icons.account_balance_wallet_rounded,
                                  label:
                                      '${_formatAmount(totalTracked)} tracked',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (recentTransactions.isEmpty)
                      const _FinanceEmptyCard()
                    else
                      ...recentTransactions.map(
                        (transaction) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TransactionCard(
                            transaction: transaction,
                            canDelete: canDeleteTransactions &&
                                transaction.canDeleteFromGymTransactions,
                            isBusy: _busyTransactionIds.contains(transaction.id),
                            onDelete: () => _deleteTransaction(transaction),
                          ),
                        ),
                      ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.go(AppRoutes.firebaseDiagnostics),
                        icon: const Icon(Icons.developer_mode_rounded),
                        label: const Text(
                          'Open Developer Firebase Diagnostics',
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

bool _canAccessFinance(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

class _FinanceLoadingCard extends StatelessWidget {
  const _FinanceLoadingCard({this.gymName});

  final String? gymName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gymName ?? 'Finance', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading current gym finance streams...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceErrorCard extends StatelessWidget {
  const _FinanceErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finance unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'The finance streams failed for the current gym.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceAccessBlocked extends StatelessWidget {
  const _FinanceAccessBlocked({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Finance unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'This module is available only for owner or staff accounts with a resolved gym context.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceEmptyCard extends StatelessWidget {
  const _FinanceEmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No finance entries found',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              'The working mobile finance providers returned no transaction documents for this gym.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceStatusCard extends StatelessWidget {
  const _FinanceStatusCard({
    required this.title,
    required this.message,
    required this.isError,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isError
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isError
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.canDelete,
    required this.isBusy,
    required this.onDelete,
  });

  final GymTransactionSummary transaction;
  final bool canDelete;
  final bool isBusy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _displayTitle(transaction),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _displaySubtitle(transaction),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatAmount(transaction.amount),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  icon: Icons.badge_outlined,
                  label: 'ID ${transaction.id}',
                ),
                if (transaction.paymentMethod != null)
                  _MetricChip(
                    icon: Icons.wallet_rounded,
                    label: transaction.paymentMethod!,
                  ),
                if (transaction.subscriptionStatus != null)
                  _MetricChip(
                    icon: Icons.verified_rounded,
                    label: transaction.subscriptionStatus!,
                  ),
                if (transaction.sourceCollection != null)
                  _MetricChip(
                    icon: Icons.folder_open_rounded,
                    label: transaction.sourceCollection!,
                  ),
              ],
            ),
            if (transaction.comment != null) ...[
              const SizedBox(height: 12),
              Text(transaction.comment!, style: theme.textTheme.bodyLarge),
            ],
            if (canDelete) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: isBusy ? null : onDelete,
                child: Text(isBusy ? 'Deleting...' : 'Delete entry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

String _displayTitle(GymTransactionSummary transaction) {
  final type = transaction.type ?? 'entry';
  final category = transaction.category;

  if (category != null && category.isNotEmpty) {
    return '$type / $category';
  }

  return type;
}

String _displaySubtitle(GymTransactionSummary transaction) {
  final parts = <String>[];

  if (transaction.clientId != null) {
    parts.add('client ${transaction.clientId}');
  }
  if (transaction.createdAt != null) {
    parts.add(_formatDateTime(transaction.createdAt!));
  }

  if (parts.isEmpty) {
    return 'Finance entry';
  }

  return parts.join('  •  ');
}

String _formatAmount(num? value) {
  if (value == null) {
    return '-';
  }

  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2);
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
