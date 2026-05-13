import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/developer_tools.dart';
import '../../../core/localization/app_currency.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_control_widgets.dart';
import '../../../core/widgets/app_date_range_filter_sheet.dart';
import '../../../core/widgets/app_person_avatar.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../clients/application/client_detail_providers.dart';
import '../../clients/application/clients_providers.dart';
import '../../clients/domain/client_detail_models.dart';
import '../../clients/domain/client_summary.dart';
import '../application/payment_actions_service.dart';
import '../application/transaction_providers.dart';
import '../domain/finance_page_snapshot.dart';
import '../domain/gym_transaction_summary.dart';

enum _FinanceTab { overview, transactions }

typedef _FinanceDateFilter = AppDateRangeFilter;

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  String? _statusMessage;
  bool _statusIsError = false;
  _FinanceDateFilter _selectedDateFilter = AppDateRangeFilter.today(
    DateTime.now(),
  );
  _FinanceTab _selectedTab = _FinanceTab.overview;
  String? _selectedClientId;
  final Set<String> _busyTransactionIds = <String>{};

  void _setStatus(String message, {required bool isError}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _pickDateFilter(ResolvedAuthSession? session) async {
    if (!_canChangeFinanceDateFilter(session) || !mounted) {
      return;
    }

    final picked = await showAppDateRangeFilterSheet(
      context: context,
      title: 'Finance range',
      selectedFilter: _selectedDateFilter,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateFilter = picked;
    });
  }

  void _openClientTransactions(String clientId) {
    setState(() {
      _selectedClientId = clientId;
      _selectedTab = _FinanceTab.transactions;
    });
  }

  void _clearClientFilter() {
    if (_selectedClientId == null) {
      return;
    }

    setState(() => _selectedClientId = null);
  }

  _FinanceDateFilter _effectiveDateFilter(ResolvedAuthSession? session) {
    if (!_canAccessFinance(session) || _canChangeFinanceDateFilter(session)) {
      return _selectedDateFilter;
    }

    return AppDateRangeFilter.today(DateTime.now());
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
    ref.watch(appCurrencyProvider);
    final session = ref.watch(bootstrapControllerProvider).session;
    final transactionsAsync = ref.watch(currentGymTransactionsProvider);
    final clientsAsync = ref.watch(currentGymClientsStreamProvider);
    final subscriptionsAsync = ref.watch(currentGymSubscriptionsProvider);
    final canDeleteTransactions = session?.role == AllClubsRole.owner;
    final isCompactMobileLayout = MediaQuery.sizeOf(context).width < 700;

    final errorMessage = _firstErrorMessage(
      transactionsAsync,
      clientsAsync,
      subscriptionsAsync,
    );
    final isLoading =
        transactionsAsync.asData == null ||
        clientsAsync.asData == null ||
        subscriptionsAsync.asData == null;

    return AppShellBody(
      expandHeight: true,
      padding: isCompactMobileLayout
          ? appControlsPagePadding
          : const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: !_canAccessFinance(session)
          ? _FinanceAccessBlocked(onBack: () => context.go(AppRoutes.app))
          : errorMessage != null
          ? _FinanceErrorCard(message: errorMessage)
          : isLoading
          ? _FinanceLoadingCard(gymName: session?.gym?.name)
          : _buildLoadedState(
              context: context,
              session: session,
              transactions:
                  transactionsAsync.asData?.value ??
                  const <GymTransactionSummary>[],
              clients: clientsAsync.asData?.value ?? const <GymClientSummary>[],
              subscriptions:
                  subscriptionsAsync.asData?.value ??
                  const <ClientSubscriptionSummary>[],
              canDeleteTransactions: canDeleteTransactions,
            ),
    );
  }

  Widget _buildLoadedState({
    required BuildContext context,
    required ResolvedAuthSession? session,
    required List<GymTransactionSummary> transactions,
    required List<GymClientSummary> clients,
    required List<ClientSubscriptionSummary> subscriptions,
    required bool canDeleteTransactions,
  }) {
    final dateFilter = _effectiveDateFilter(session);
    final clientsById = <String, GymClientSummary>{
      for (final client in clients) client.id: client,
    };
    final financeSnapshot = buildFinancePageSnapshot(
      transactions: transactions,
      subscriptions: subscriptions,
      clientsById: clientsById,
      from: dateFilter.from,
      to: dateFilter.to,
      selectedClientId: _selectedClientId,
    );
    final isCompactMobileLayout = MediaQuery.sizeOf(context).width < 700;
    final rankedOverviews = [...financeSnapshot.overviews]
      ..sort((left, right) {
        final revenueCompare = right.totalRevenue.compareTo(left.totalRevenue);
        if (revenueCompare != 0) {
          return revenueCompare;
        }

        return right.debt.compareTo(left.debt);
      });
    final visibleOverviewItems = isCompactMobileLayout
        ? rankedOverviews
        : financeSnapshot.overviews;
    final visibleTransactions = financeSnapshot.transactions;
    final visibleTotalAmount = financeSnapshot.filteredTotal;

    if (isCompactMobileLayout) {
      return _buildCompactMobileState(
        context: context,
        session: session,
        dateFilter: dateFilter,
        financeSnapshot: financeSnapshot,
        visibleOverviewItems: visibleOverviewItems,
        visibleTransactions: visibleTransactions,
        clientsById: clientsById,
        visibleTotalAmount: visibleTotalAmount,
      );
    }

    return ListView(
      controller: ScrollController(keepScrollOffset: false),
      children: [
        if (_statusMessage != null) ...[
          _FinanceStatusCard(
            title: _statusIsError ? 'Finance action failed' : 'Finance',
            message: _statusMessage!,
            isError: _statusIsError,
          ),
          const SizedBox(height: 12),
        ],
        _FinanceHeaderCard(
          gymName: session?.gym?.name,
          dateFilter: dateFilter,
          totalRevenue: financeSnapshot.totalRevenue,
          totalDebt: financeSnapshot.totalDebt,
          clientCount: financeSnapshot.overviews.length,
          entryCount: financeSnapshot.transactions.length,
          onPickDate: _canChangeFinanceDateFilter(session)
              ? () => _pickDateFilter(session)
              : null,
        ),
        const SizedBox(height: 16),
        _FinanceTabStrip(
          selectedTab: _selectedTab,
          onTabSelected: (tab) => setState(() => _selectedTab = tab),
        ),
        const SizedBox(height: 12),
        if (_selectedTab == _FinanceTab.overview) ...[
          _FinancePulseCard(
            dateFilter: dateFilter,
            overviews: financeSnapshot.overviews,
            transactions: financeSnapshot.dateFilteredTransactions,
          ),
          const SizedBox(height: 12),
          _FinanceMethodBreakdownCard(
            transactions: financeSnapshot.dateFilteredTransactions,
          ),
          const SizedBox(height: 12),
          _FinanceDebtWatchCard(
            items: financeSnapshot.overviews,
            onClientTap: _openClientTransactions,
          ),
          const SizedBox(height: 12),
          _FinanceOverviewCard(
            dateFilter: dateFilter,
            items: financeSnapshot.overviews,
            clientsById: clientsById,
            onClientTap: _openClientTransactions,
          ),
        ] else ...[
          _FinanceTransactionsInsightsCard(
            transactions: financeSnapshot.transactions,
            totalAmount: financeSnapshot.filteredTotal,
          ),
          const SizedBox(height: 12),
          _FinanceTransactionsCard(
            dateFilter: dateFilter,
            transactions: visibleTransactions,
            selectedClientName: financeSnapshot.selectedClientName,
            clientsById: clientsById,
            fallbackNamesByClientId: financeSnapshot.fallbackNamesByClientId,
            totalAmount: visibleTotalAmount,
            canDeleteTransactions: canDeleteTransactions,
            busyTransactionIds: _busyTransactionIds,
            onClientTap: _openClientTransactions,
            onClearClient: _clearClientFilter,
            onDeleteTransaction: _deleteTransaction,
          ),
        ],
        if (showDeveloperDiagnosticsShortcut) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => openDeveloperDiagnostics(context),
            icon: const Icon(Icons.developer_mode_rounded),
            label: const Text('Open Developer Firebase Diagnostics'),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactMobileState({
    required BuildContext context,
    required ResolvedAuthSession? session,
    required _FinanceDateFilter dateFilter,
    required FinancePageSnapshot financeSnapshot,
    required List<FinanceClientOverviewItem> visibleOverviewItems,
    required List<GymTransactionSummary> visibleTransactions,
    required Map<String, GymClientSummary> clientsById,
    required num visibleTotalAmount,
  }) {
    return CustomScrollView(
      controller: ScrollController(keepScrollOffset: false),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: AppControlsSliverHeaderDelegate(
            extent: appControlsHeaderExtent,
            child: _FinanceControlsHeader(
              dateFilter: dateFilter,
              canPickDate: _canChangeFinanceDateFilter(session),
              selectedTab: _selectedTab,
              overviewCount: financeSnapshot.overviews.length,
              transactionCount: financeSnapshot.transactions.length,
              onPickDate: _canChangeFinanceDateFilter(session)
                  ? () => _pickDateFilter(session)
                  : null,
              onTabSelected: (tab) => setState(() => _selectedTab = tab),
            ),
          ),
        ),
        if (_statusMessage != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: _FinanceStatusCard(
                title: _statusIsError ? 'Finance action failed' : 'Finance',
                message: _statusMessage!,
                isError: _statusIsError,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _FinanceCompactSummary(
              selectedTab: _selectedTab,
              totalRevenue: financeSnapshot.totalRevenue,
              totalDebt: financeSnapshot.totalDebt,
              clientCount: financeSnapshot.overviews.length,
              entryCount: financeSnapshot.transactions.length,
            ),
          ),
        ),
        if (_selectedTab == _FinanceTab.overview) ...[
          if (visibleOverviewItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _FinanceInlineEmptyState(
                  title: 'No finance activity yet',
                  message: _emptyStateRangeMessage(
                    prefix: 'No client revenue or debt was found',
                    dateFilter: dateFilter,
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final item = visibleOverviewItems[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == visibleOverviewItems.length - 1 ? 0 : 10,
                    ),
                    child: _FinanceCompactOverviewTile(
                      item: item,
                      clientImageUrl: _financeClientImageUrl(
                        item.clientId,
                        clientsById,
                      ),
                      onTap: () => _openClientTransactions(item.clientId),
                    ),
                  );
                }, childCount: visibleOverviewItems.length),
              ),
            ),
        ] else ...[
          if (financeSnapshot.selectedClientName != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _FinanceFilterChip(
                    label: financeSnapshot.selectedClientName!,
                    onClear: _clearClientFilter,
                  ),
                ),
              ),
            ),
          if (visibleTransactions.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _FinanceInlineEmptyState(
                  title: 'No matching transactions',
                  message: financeSnapshot.selectedClientName == null
                      ? _emptyStateRangeMessage(
                          prefix: 'No transaction entries were found',
                          dateFilter: dateFilter,
                        )
                      : _emptyStateRangeMessage(
                          prefix:
                              'No transactions were found for ${financeSnapshot.selectedClientName}',
                          dateFilter: dateFilter,
                        ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(top: 10),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final transaction = visibleTransactions[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == visibleTransactions.length - 1 ? 0 : 10,
                    ),
                    child: _FinanceCompactTransactionTile(
                      transaction: transaction,
                      clientName: resolveFinanceClientLabel(
                        transaction: transaction,
                        clientsById: clientsById,
                        fallbackNamesByClientId:
                            financeSnapshot.fallbackNamesByClientId,
                      ),
                      clientImageUrl: _financeClientImageUrl(
                        transaction.clientId,
                        clientsById,
                      ),
                      canFilterByClient: _hasClientId(transaction.clientId),
                      onClientTap: _hasClientId(transaction.clientId)
                          ? () => _openClientTransactions(
                              transaction.clientId!.trim(),
                            )
                          : null,
                    ),
                  );
                }, childCount: visibleTransactions.length),
              ),
            ),
        ],
        if (showDeveloperDiagnosticsShortcut)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: () => openDeveloperDiagnostics(context),
                icon: const Icon(Icons.developer_mode_rounded),
                label: const Text('Open Developer Firebase Diagnostics'),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 116)),
      ],
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

bool _canChangeFinanceDateFilter(ResolvedAuthSession? session) {
  return session?.role == AllClubsRole.owner;
}

class _FinanceControlsHeader extends StatelessWidget {
  const _FinanceControlsHeader({
    required this.dateFilter,
    required this.canPickDate,
    required this.selectedTab,
    required this.overviewCount,
    required this.transactionCount,
    required this.onTabSelected,
    this.onPickDate,
  });

  final _FinanceDateFilter dateFilter;
  final bool canPickDate;
  final _FinanceTab selectedTab;
  final int overviewCount;
  final int transactionCount;
  final ValueChanged<_FinanceTab> onTabSelected;
  final VoidCallback? onPickDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCalendarControlButton(
          label: _dateFilterLabel(dateFilter),
          onTap: onPickDate,
          trailingIcon: canPickDate
              ? Icons.edit_calendar_rounded
              : Icons.lock_outline_rounded,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          child: Row(
            children: [
              Expanded(
                child: AppControlTogglePill(
                  label: 'Overview',
                  count: overviewCount,
                  selected: selectedTab == _FinanceTab.overview,
                  onTap: () => onTabSelected(_FinanceTab.overview),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: AppControlTogglePill(
                  label: 'Transactions',
                  count: transactionCount,
                  selected: selectedTab == _FinanceTab.transactions,
                  onTap: () => onTabSelected(_FinanceTab.transactions),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinanceCompactSummary extends StatelessWidget {
  const _FinanceCompactSummary({
    required this.selectedTab,
    required this.totalRevenue,
    required this.totalDebt,
    required this.clientCount,
    required this.entryCount,
  });

  final _FinanceTab selectedTab;
  final num totalRevenue;
  final num totalDebt;
  final int clientCount;
  final int entryCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedTab == _FinanceTab.overview) ...[
          const _FinanceSectionHead(
            icon: Icons.grid_view_rounded,
            title: 'Finance Overview',
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FinanceMetricPill(
                label: 'Revenue',
                value: _formatMoney(totalRevenue, withUnit: true),
                tone: _FinanceTone.success,
              ),
              const SizedBox(width: 6),
              _FinanceMetricPill(
                label: 'Debt',
                value: _formatMoney(totalDebt, withUnit: true),
                tone: totalDebt > 0
                    ? _FinanceTone.warning
                    : _FinanceTone.subtle,
              ),
              const SizedBox(width: 6),
              _FinanceMetricPill(
                label: 'Clients',
                value: '$clientCount',
                tone: _FinanceTone.info,
              ),
              const SizedBox(width: 6),
              _FinanceMetricPill(label: 'Entries', value: '$entryCount'),
            ],
          ),
        ),
      ],
    );
  }
}

class _FinanceMetricPill extends StatelessWidget {
  const _FinanceMetricPill({
    this.label,
    required this.value,
    this.tone = _FinanceTone.defaultTone,
  });

  final String? label;
  final String value;
  final _FinanceTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _toneColors(theme, tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _alpha(colors.background, 0.95),
            _alpha(colors.background, 0.78),
          ],
        ),
        border: Border.all(color: _alpha(colors.border, 0.88)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null && label!.trim().isNotEmpty) ...[
            Text(
              label!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: _alpha(AppColors.secondary, 0.86),
                fontSize: 10.3,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.foreground,
              fontSize: 10.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceCompactOverviewTile extends StatelessWidget {
  const _FinanceCompactOverviewTile({
    required this.item,
    required this.clientImageUrl,
    required this.onTap,
  });

  final FinanceClientOverviewItem item;
  final String? clientImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.panel,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceMonogram(
                label: item.clientName,
                imageUrl: clientImageUrl,
                size: 54,
                tone: item.debt > 0 ? _FinanceTone.warning : _FinanceTone.info,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 15,
                          color: item.debt > 0
                              ? AppColors.accent
                              : AppColors.mutedInk,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _formatMoney(item.debt, withUnit: true),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: item.debt > 0
                                  ? AppColors.accent
                                  : AppColors.mutedInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _FinanceMetricPill(
                    label: 'Revenue',
                    value: _formatMoney(item.totalRevenue, withUnit: true),
                    tone: _FinanceTone.success,
                  ),
                  const SizedBox(height: 10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: _alpha(AppColors.primary, 0.72),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceCompactTransactionTile extends StatelessWidget {
  const _FinanceCompactTransactionTile({
    required this.transaction,
    required this.clientName,
    required this.clientImageUrl,
    required this.canFilterByClient,
    this.onClientTap,
  });

  final GymTransactionSummary transaction;
  final String clientName;
  final String? clientImageUrl;
  final bool canFilterByClient;
  final VoidCallback? onClientTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = transaction.amount ?? 0;
    final transactionTypeLabel = _transactionTypeLabel(transaction);
    final transactionTypeIcon = _transactionTypeIcon(transaction);
    final transactionMethodLabel = _transactionMethodLabel(transaction);
    final transactionMethodIcon = _paymentMethodIcon(transaction.paymentMethod);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onClientTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.panel,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A5F).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceMonogram(
                label: clientName,
                imageUrl: clientImageUrl,
                size: 54,
                tone: canFilterByClient
                    ? _FinanceTone.info
                    : _FinanceTone.subtle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            clientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 124,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: _FinanceMetricPill(
                                value: _formatMoney(
                                  amount,
                                  withUnit: true,
                                  showSign: true,
                                ),
                                tone: amount < 0
                                    ? _FinanceTone.danger
                                    : _FinanceTone.success,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (transactionTypeLabel != null ||
                              transactionTypeIcon != null)
                            _FinancePill(
                              label: transactionTypeLabel,
                              tone: _typeTone(transaction),
                              icon: transactionTypeIcon,
                            ),
                          if ((transactionTypeLabel != null ||
                                  transactionTypeIcon != null) &&
                              transactionMethodLabel != null)
                            const SizedBox(width: 6),
                          if (transactionMethodLabel != null)
                            _FinancePill(
                              label: transactionMethodLabel,
                              tone: _methodTone(transaction.paymentMethod),
                              icon: transactionMethodIcon,
                            ),
                        ],
                      ),
                    ),
                    if (transaction.comment != null &&
                        transaction.comment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        transaction.comment!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceHeaderCard extends StatelessWidget {
  const _FinanceHeaderCard({
    required this.gymName,
    required this.dateFilter,
    required this.totalRevenue,
    required this.totalDebt,
    required this.clientCount,
    required this.entryCount,
    this.onPickDate,
  });

  final String? gymName;
  final _FinanceDateFilter dateFilter;
  final num totalRevenue;
  final num totalDebt;
  final int clientCount;
  final int entryCount;
  final VoidCallback? onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF223247),
                const Color(0xFF182330),
                _alpha(const Color(0xFF111923), 0.96),
              ],
            ),
          ),
          child: Stack(
            children: [
              const Positioned(
                top: -24,
                right: -8,
                child: _FinanceBackdropOrb(size: 132, color: Color(0x2284B5FF)),
              ),
              const Positioned(
                bottom: -76,
                left: -30,
                child: _FinanceBackdropOrb(size: 182, color: Color(0x1559D690)),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: _alpha(Colors.white, 0.06),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _alpha(Colors.white, 0.08)),
                      ),
                      child: Text(
                        'Finance Board',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: AppColors.secondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      gymName ?? 'Finance',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dateFilterDescription(dateFilter),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _alpha(AppColors.secondary, 0.86),
                      ),
                    ),
                    if (onPickDate != null) ...[
                      const SizedBox(height: 18),
                      OutlinedButton.icon(
                        onPressed: onPickDate,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.ink,
                          backgroundColor: _alpha(Colors.white, 0.04),
                          side: BorderSide(color: _alpha(Colors.white, 0.08)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                        icon: const Icon(Icons.calendar_today_rounded),
                        label: Text(_dateFilterLabel(dateFilter)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      _formatMoney(totalRevenue, withUnit: true),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Selected range revenue',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _alpha(AppColors.secondary, 0.74),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _FinanceHeroMetric(
                          icon: Icons.warning_amber_rounded,
                          label: 'Debt',
                          value: _formatMoney(totalDebt, withUnit: true),
                          tone: totalDebt > 0
                              ? _FinanceTone.warning
                              : _FinanceTone.subtle,
                        ),
                        _FinanceHeroMetric(
                          icon: Icons.group_rounded,
                          label: 'Clients',
                          value: '$clientCount',
                          tone: _FinanceTone.info,
                        ),
                        _FinanceHeroMetric(
                          icon: Icons.receipt_long_rounded,
                          label: 'Entries',
                          value: '$entryCount',
                        ),
                        _FinanceHeroMetric(
                          icon: Icons.query_stats_rounded,
                          label: 'Range',
                          value: _dateFilterLabel(dateFilter),
                          tone: _FinanceTone.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceBackdropOrb extends StatelessWidget {
  const _FinanceBackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: _alpha(Colors.white, 0.04)),
        ),
      ),
    );
  }
}

class _FinanceHeroMetric extends StatelessWidget {
  const _FinanceHeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    this.tone = _FinanceTone.defaultTone,
  });

  final IconData icon;
  final String label;
  final String value;
  final _FinanceTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _toneColors(theme, tone);

    return Container(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 188),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _alpha(colors.background, 0.96),
            _alpha(colors.background, 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _alpha(colors.border, 0.94)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _alpha(colors.foreground, 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: colors.foreground),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: _alpha(AppColors.secondary, 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _FinancePulseCard extends StatelessWidget {
  const _FinancePulseCard({
    required this.dateFilter,
    required this.overviews,
    required this.transactions,
  });

  final _FinanceDateFilter dateFilter;
  final List<FinanceClientOverviewItem> overviews;
  final List<GymTransactionSummary> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalRevenue = overviews.fold<num>(
      0,
      (sum, item) => sum + item.totalRevenue,
    );
    final totalDebt = overviews.fold<num>(0, (sum, item) => sum + item.debt);
    final liveClients = overviews.where((item) => item.totalRevenue > 0).length;
    final debtClients = overviews.where((item) => item.debt > 0).length;
    final positiveEntries = transactions.where(
      (item) => (item.amount ?? 0) > 0,
    );
    final topClient = [...overviews]
      ..sort((left, right) => right.totalRevenue.compareTo(left.totalRevenue));
    final leadName = topClient.isEmpty ? null : topClient.first.clientName;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF20314A),
              const Color(0xFF17222F),
              _alpha(const Color(0xFF394A78), 0.88),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finance Pulse', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                _dateFilterDescription(dateFilter),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Text(
                _formatMoney(totalRevenue, withUnit: true),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                leadName == null
                    ? 'No ledger leader yet. New payments will appear here.'
                    : '$leadName is leading the selected period.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FinanceMiniStat(
                    label: 'Live clients',
                    value: '$liveClients',
                    tone: _FinanceTone.success,
                  ),
                  _FinanceMiniStat(
                    label: 'Debt watch',
                    value: '$debtClients',
                    tone: debtClients > 0
                        ? _FinanceTone.warning
                        : _FinanceTone.subtle,
                  ),
                  _FinanceMiniStat(
                    label: 'Payments',
                    value: '${positiveEntries.length}',
                    tone: _FinanceTone.info,
                  ),
                  _FinanceMiniStat(
                    label: 'Outstanding',
                    value: _formatMoney(totalDebt, withUnit: true),
                    tone: totalDebt > 0
                        ? _FinanceTone.warning
                        : _FinanceTone.subtle,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceMethodBreakdownCard extends StatelessWidget {
  const _FinanceMethodBreakdownCard({required this.transactions});

  final List<GymTransactionSummary> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summaries = _buildMethodSummaries(transactions);
    final totalVolume = summaries.fold<num>(
      0,
      (sum, item) => sum + item.amount.abs(),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment Channels', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Where the selected finance flow is moving right now.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            if (summaries.isEmpty)
              const _FinanceInlineEmptyState(
                title: 'No payment methods yet',
                message:
                    'As soon as a finance entry is created, the channel split will appear here.',
              )
            else
              ...summaries
                  .take(4)
                  .map(
                    (summary) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _FinanceMethodRow(
                        summary: summary,
                        share: totalVolume == 0
                            ? 0
                            : summary.amount.abs() / totalVolume,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _FinanceDebtWatchCard extends StatelessWidget {
  const _FinanceDebtWatchCard({required this.items, required this.onClientTap});

  final List<FinanceClientOverviewItem> items;
  final ValueChanged<String> onClientTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debtors = [...items]
      ..removeWhere((item) => item.debt <= 0)
      ..sort((left, right) => right.debt.compareTo(left.debt));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Debt Watch', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              'Clients that need follow-up first.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            if (debtors.isEmpty)
              const _FinanceInlineEmptyState(
                title: 'No open debt',
                message:
                    'Great. The current selection has no clients waiting on debt follow-up.',
              )
            else
              ...debtors
                  .take(3)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DebtWatchRow(
                        item: item,
                        onTap: () => onClientTap(item.clientId),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _FinanceTransactionsInsightsCard extends StatelessWidget {
  const _FinanceTransactionsInsightsCard({
    required this.transactions,
    required this.totalAmount,
  });

  final List<GymTransactionSummary> transactions;
  final num totalAmount;

  @override
  Widget build(BuildContext context) {
    final incoming = transactions.fold<num>(
      0,
      (sum, item) => sum + ((item.amount ?? 0) > 0 ? item.amount ?? 0 : 0),
    );
    final outgoing = transactions.fold<num>(
      0,
      (sum, item) =>
          sum + ((item.amount ?? 0) < 0 ? (item.amount ?? 0).abs() : 0),
    );
    final packageCount = transactions.where(_isPackageStyleTransaction).length;
    final debtCount = transactions
        .where(
          (item) => (item.paymentMethod ?? '').trim().toLowerCase() == 'debt',
        )
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transaction Snapshot',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'A quick read before you scan the ledger.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _FinanceMiniStat(
                  label: 'Incoming',
                  value: _formatMoney(incoming, withUnit: true),
                  tone: _FinanceTone.success,
                ),
                _FinanceMiniStat(
                  label: 'Outgoing',
                  value: _formatMoney(outgoing, withUnit: true),
                  tone: outgoing > 0
                      ? _FinanceTone.danger
                      : _FinanceTone.subtle,
                ),
                _FinanceMiniStat(
                  label: 'Package rows',
                  value: '$packageCount',
                  tone: _FinanceTone.info,
                ),
                _FinanceMiniStat(
                  label: 'Debt rows',
                  value: '$debtCount',
                  tone: debtCount > 0
                      ? _FinanceTone.warning
                      : _FinanceTone.subtle,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _FinanceNetBanner(totalAmount: totalAmount),
          ],
        ),
      ),
    );
  }
}

class _FinanceTabStrip extends StatelessWidget {
  const _FinanceTabStrip({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final _FinanceTab selectedTab;
  final ValueChanged<_FinanceTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _alpha(AppColors.panelRaised, 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _alpha(AppColors.border, 0.86)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FinanceTabButton(
              icon: Icons.grid_view_rounded,
              label: 'Overview',
              selected: selectedTab == _FinanceTab.overview,
              onTap: () => onTabSelected(_FinanceTab.overview),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FinanceTabButton(
              icon: Icons.receipt_long_rounded,
              label: 'Transactions',
              selected: selectedTab == _FinanceTab.transactions,
              onTap: () => onTabSelected(_FinanceTab.transactions),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceTabButton extends StatelessWidget {
  const _FinanceTabButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF7FAFF), Color(0xFFDCE4EE)],
                  )
                : null,
            border: Border.all(
              color: selected ? _alpha(Colors.white, 0.42) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? AppColors.canvasStrong : AppColors.secondary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? AppColors.canvasStrong
                        : AppColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceOverviewCard extends StatelessWidget {
  const _FinanceOverviewCard({
    required this.dateFilter,
    required this.items,
    required this.clientsById,
    required this.onClientTap,
  });

  final _FinanceDateFilter dateFilter;
  final List<FinanceClientOverviewItem> items;
  final Map<String, GymClientSummary> clientsById;
  final ValueChanged<String> onClientTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FinanceSectionHead(
              icon: Icons.people_alt_rounded,
              title: 'Client Overview',
              subtitle: 'Tap a client to open filtered transactions.',
              trailing: items.isEmpty
                  ? null
                  : _FinanceCountBadge(label: '${items.length}'),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              _FinanceInlineEmptyState(
                title: 'No finance activity yet',
                message: _emptyStateRangeMessage(
                  prefix: 'No client revenue or debt was found',
                  dateFilter: dateFilter,
                ),
              )
            else
              ...List.generate(items.length, (index) {
                final item = items[index];
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == items.length - 1 ? 0 : 12,
                  ),
                  child: _FinanceOverviewRow(
                    item: item,
                    clientImageUrl: _financeClientImageUrl(
                      item.clientId,
                      clientsById,
                    ),
                    onTap: () => onClientTap(item.clientId),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FinanceOverviewRow extends StatelessWidget {
  const _FinanceOverviewRow({
    required this.item,
    required this.clientImageUrl,
    required this.onTap,
  });

  final FinanceClientOverviewItem item;
  final String? clientImageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debtColor = item.debt > 0 ? AppColors.accent : AppColors.mutedInk;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _alpha(AppColors.panelRaised, 0.82),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _alpha(AppColors.border, 0.86)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FinanceMonogram(
                    label: item.clientName,
                    imageUrl: clientImageUrl,
                    tone: item.debt > 0
                        ? _FinanceTone.warning
                        : _FinanceTone.info,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.clientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.debt > 0
                              ? 'Needs debt follow-up'
                              : 'Healthy payment flow',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _alpha(AppColors.success, 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _alpha(AppColors.success, 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Revenue', style: theme.textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(
                          _formatMoney(item.totalRevenue, withUnit: true),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _FinanceMetaPill(
                      label: 'Debt',
                      value: _formatMoney(item.debt, withUnit: true),
                      tone: item.debt > 0
                          ? _FinanceTone.warning
                          : _FinanceTone.subtle,
                      valueColor: debtColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FinanceMetaPill(
                      label: 'Last activity',
                      value: _formatRelativeActivity(item.lastActivityAt),
                      alignEnd: true,
                      tone: _FinanceTone.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: _alpha(AppColors.primary, 0.76),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceSectionHead extends StatelessWidget {
  const _FinanceSectionHead({
    required this.icon,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _alpha(AppColors.primary, 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _alpha(AppColors.border, 0.82)),
          ),
          child: Icon(icon, size: 20, color: AppColors.secondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class _FinanceCountBadge extends StatelessWidget {
  const _FinanceCountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _alpha(AppColors.panelRaised, 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _alpha(AppColors.border, 0.82)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: AppColors.secondary),
      ),
    );
  }
}

class _FinanceMonogram extends StatelessWidget {
  const _FinanceMonogram({
    required this.label,
    this.imageUrl,
    this.size = 48,
    this.tone = _FinanceTone.info,
  });

  final String label;
  final String? imageUrl;
  final double size;
  final _FinanceTone tone;

  @override
  Widget build(BuildContext context) {
    return AppClientCardAvatar(
      label: label,
      fallback: 'C',
      imageUrl: imageUrl,
      size: size,
      tone: _avatarToneForFinanceTone(tone),
    );
  }
}

class _FinanceMetaPill extends StatelessWidget {
  const _FinanceMetaPill({
    required this.label,
    required this.value,
    this.tone = _FinanceTone.subtle,
    this.alignEnd = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final _FinanceTone tone;
  final bool alignEnd;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _toneColors(theme, tone);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _alpha(colors.background, 0.86),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _alpha(colors.border, 0.86)),
      ),
      child: Column(
        crossAxisAlignment: alignEnd
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: valueColor ?? colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceMiniStat extends StatelessWidget {
  const _FinanceMiniStat({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final String value;
  final _FinanceTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _toneColors(theme, tone);

    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _alpha(colors.background, 0.98),
            _alpha(colors.background, 0.78),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _alpha(colors.border, 0.9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.foreground,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceMethodRow extends StatelessWidget {
  const _FinanceMethodRow({required this.summary, required this.share});

  final _FinanceMethodSummary summary;
  final double share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _toneColors(theme, _methodTone(summary.method));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _paymentMethodLabel(summary.method),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatMoney(summary.amount, withUnit: true),
              style: theme.textTheme.titleMedium?.copyWith(
                color: colors.foreground,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: share.clamp(0, 1),
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
          ),
        ),
        const SizedBox(height: 6),
        Text('${summary.count} entries', style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _DebtWatchRow extends StatelessWidget {
  const _DebtWatchRow({required this.item, required this.onTap});

  final FinanceClientOverviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _alpha(const Color(0xFF2E3B49), 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _alpha(AppColors.border, 0.9)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.clientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last activity ${_formatRelativeActivity(item.lastActivityAt).toLowerCase()}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatMoney(item.debt, withUnit: true),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: _alpha(AppColors.primary, 0.72),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinanceNetBanner extends StatelessWidget {
  const _FinanceNetBanner({required this.totalAmount});

  final num totalAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = totalAmount > 0
        ? _FinanceTone.success
        : totalAmount < 0
        ? _FinanceTone.danger
        : _FinanceTone.subtle;
    final colors = _toneColors(theme, tone);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_rounded, color: colors.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              totalAmount == 0
                  ? 'The visible ledger is currently balanced.'
                  : totalAmount > 0
                  ? 'Visible ledger is net positive in the selected filter.'
                  : 'Visible ledger is net negative in the selected filter.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinanceTransactionsCard extends StatelessWidget {
  const _FinanceTransactionsCard({
    required this.dateFilter,
    required this.transactions,
    required this.selectedClientName,
    required this.clientsById,
    required this.fallbackNamesByClientId,
    required this.totalAmount,
    required this.canDeleteTransactions,
    required this.busyTransactionIds,
    required this.onClientTap,
    required this.onClearClient,
    required this.onDeleteTransaction,
  });

  final _FinanceDateFilter dateFilter;
  final List<GymTransactionSummary> transactions;
  final String? selectedClientName;
  final Map<String, GymClientSummary> clientsById;
  final Map<String, String> fallbackNamesByClientId;
  final num totalAmount;
  final bool canDeleteTransactions;
  final Set<String> busyTransactionIds;
  final ValueChanged<String> onClientTap;
  final VoidCallback onClearClient;
  final ValueChanged<GymTransactionSummary> onDeleteTransaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalColor = _moneyColor(theme, totalAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FinanceSectionHead(
              icon: Icons.receipt_long_rounded,
              title: 'Transactions',
              subtitle: _dateFilterDescription(dateFilter),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _alpha(totalColor, 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _alpha(totalColor, 0.26)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(
                      _formatMoney(totalAmount, withUnit: true, showSign: true),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: totalColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selectedClientName != null) ...[
              const SizedBox(height: 14),
              _FinanceFilterChip(
                label: selectedClientName!,
                onClear: onClearClient,
              ),
            ],
            const SizedBox(height: 14),
            if (transactions.isEmpty)
              _FinanceInlineEmptyState(
                title: 'No matching transactions',
                message: selectedClientName == null
                    ? _emptyStateRangeMessage(
                        prefix: 'No transaction entries were found',
                        dateFilter: dateFilter,
                      )
                    : _emptyStateRangeMessage(
                        prefix:
                            'No transactions were found for $selectedClientName',
                        dateFilter: dateFilter,
                      ),
              )
            else
              ...List.generate(transactions.length, (index) {
                final transaction = transactions[index];
                final clientName = resolveFinanceClientLabel(
                  transaction: transaction,
                  clientsById: clientsById,
                  fallbackNamesByClientId: fallbackNamesByClientId,
                );

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == transactions.length - 1 ? 0 : 12,
                  ),
                  child: _FinanceTransactionRow(
                    transaction: transaction,
                    clientName: clientName,
                    clientImageUrl: _financeClientImageUrl(
                      transaction.clientId,
                      clientsById,
                    ),
                    canFilterByClient: _hasClientId(transaction.clientId),
                    canDelete:
                        canDeleteTransactions &&
                        transaction.canDeleteFromGymTransactions,
                    isBusy: busyTransactionIds.contains(transaction.id),
                    onClientTap: _hasClientId(transaction.clientId)
                        ? () => onClientTap(transaction.clientId!.trim())
                        : null,
                    onDelete: () => onDeleteTransaction(transaction),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _FinanceTransactionRow extends StatelessWidget {
  const _FinanceTransactionRow({
    required this.transaction,
    required this.clientName,
    required this.clientImageUrl,
    required this.canFilterByClient,
    required this.canDelete,
    required this.isBusy,
    required this.onDelete,
    this.onClientTap,
  });

  final GymTransactionSummary transaction;
  final String clientName;
  final String? clientImageUrl;
  final bool canFilterByClient;
  final bool canDelete;
  final bool isBusy;
  final VoidCallback onDelete;
  final VoidCallback? onClientTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = transaction.amount ?? 0;
    final amountColor = _moneyColor(theme, amount);
    final transactionTypeLabel = _transactionTypeLabel(transaction);
    final transactionTypeIcon = _transactionTypeIcon(transaction);
    final transactionMethodLabel = _transactionMethodLabel(transaction);
    final transactionMethodIcon = _paymentMethodIcon(transaction.paymentMethod);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _alpha(AppColors.panelRaised, 0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _alpha(AppColors.border, 0.86)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _alpha(AppColors.primary, 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _alpha(AppColors.border, 0.82)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTransactionDate(transaction.createdAt),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _alpha(amountColor, 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _alpha(amountColor, 0.26)),
                ),
                child: Text(
                  _formatMoney(amount, withUnit: true, showSign: true),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: amountColor,
                  ),
                ),
              ),
              if (canDelete)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: isBusy
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            color: _alpha(theme.colorScheme.error, 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Delete entry',
                          ),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FinanceMonogram(
                label: clientName,
                imageUrl: clientImageUrl,
                size: 46,
                tone: canFilterByClient
                    ? _FinanceTone.info
                    : _FinanceTone.subtle,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (canFilterByClient && onClientTap != null)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onClientTap,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              clientName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        clientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (transactionTypeLabel != null ||
                            transactionTypeIcon != null)
                          _FinancePill(
                            label: transactionTypeLabel,
                            tone: _typeTone(transaction),
                            icon: transactionTypeIcon,
                          ),
                        if (transactionMethodLabel != null)
                          _FinancePill(
                            label: transactionMethodLabel,
                            tone: _methodTone(transaction.paymentMethod),
                            icon: transactionMethodIcon,
                          ),
                      ],
                    ),
                    if (transaction.comment != null &&
                        transaction.comment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        transaction.comment!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceFilterChip extends StatelessWidget {
  const _FinanceFilterChip({required this.label, required this.onClear});

  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF404A99), Color(0xFF30396F)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x665967D0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.person_search_rounded,
            size: 16,
            color: Color(0xFFB8BEFF),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFFB8BEFF),
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Color(0xFFB8BEFF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancePill extends StatelessWidget {
  const _FinancePill({this.label, required this.tone, this.icon});

  final String? label;
  final _FinanceTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _toneColors(theme, tone);
    final hasLabel = label != null && label!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _alpha(colors.background, 0.98),
            _alpha(colors.background, 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _alpha(colors.border, 0.92)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.foreground),
            if (hasLabel) const SizedBox(width: 5),
          ],
          if (hasLabel)
            Text(
              label!,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.foreground,
                fontSize: 11.2,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _FinanceInlineEmptyState extends StatelessWidget {
  const _FinanceInlineEmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _alpha(theme.colorScheme.surfaceContainerHighest, 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _alpha(AppColors.border, 0.82)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _alpha(AppColors.primary, 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.inbox_rounded, color: AppColors.secondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
              'Loading finance overview, transactions, and client balances...',
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
              'The finance data could not be loaded for the current gym.',
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

enum _FinanceTone { defaultTone, subtle, success, warning, info, danger }

class _FinanceMethodSummary {
  const _FinanceMethodSummary({
    required this.method,
    required this.amount,
    required this.count,
  });

  final String method;
  final num amount;
  final int count;
}

({Color background, Color foreground, Color border}) _toneColors(
  ThemeData theme,
  _FinanceTone tone,
) {
  return switch (tone) {
    _FinanceTone.success => (
      background: const Color(0xFF1E4C3F),
      foreground: const Color(0xFFE8FFF3),
      border: const Color(0x6656B88E),
    ),
    _FinanceTone.warning => (
      background: _alpha(AppColors.accent, 0.16),
      foreground: AppColors.accent,
      border: _alpha(AppColors.accent, 0.34),
    ),
    _FinanceTone.info => (
      background: const Color(0xFF2E3F77),
      foreground: const Color(0xFFAFC4FF),
      border: const Color(0x554D68C3),
    ),
    _FinanceTone.danger => (
      background: _alpha(theme.colorScheme.error, 0.16),
      foreground: theme.colorScheme.error,
      border: _alpha(theme.colorScheme.error, 0.34),
    ),
    _FinanceTone.subtle => (
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: AppColors.secondary,
      border: _alpha(AppColors.border, 0.66),
    ),
    _FinanceTone.defaultTone => (
      background: theme.colorScheme.surfaceContainerHighest,
      foreground: AppColors.ink,
      border: _alpha(AppColors.border, 0.66),
    ),
  };
}

String? _firstErrorMessage(
  AsyncValue<Object?> first,
  AsyncValue<Object?> second,
  AsyncValue<Object?> third,
) {
  for (final value in [first, second, third]) {
    final error = value.asError?.error;
    if (error != null) {
      return error.toString().replaceFirst('Exception: ', '');
    }
  }

  return null;
}

bool _hasClientId(String? clientId) {
  return clientId != null && clientId.trim().isNotEmpty;
}

String? _financeClientImageUrl(
  String? clientId,
  Map<String, GymClientSummary> clientsById,
) {
  if (!_hasClientId(clientId)) {
    return null;
  }

  return clientsById[clientId!.trim()]?.imageUrl;
}

AppClientAvatarTone _avatarToneForFinanceTone(_FinanceTone tone) {
  return switch (tone) {
    _FinanceTone.info => AppClientAvatarTone.info,
    _FinanceTone.success => AppClientAvatarTone.success,
    _FinanceTone.warning => AppClientAvatarTone.warning,
    _FinanceTone.danger => AppClientAvatarTone.danger,
    _FinanceTone.subtle => AppClientAvatarTone.subtle,
    _FinanceTone.defaultTone => AppClientAvatarTone.defaultTone,
  };
}

String _formatMoney(num value, {bool withUnit = false, bool showSign = false}) {
  return formatAppMoney(value, withUnit: withUnit, showSign: showSign);
}

String _formatTransactionDate(DateTime? value) {
  if (value == null) {
    return 'Unknown date';
  }

  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year.toString().padLeft(4, '0');
  return '$day.$month.$year';
}

String _formatRelativeActivity(DateTime? value) {
  if (value == null) {
    return 'No activity';
  }

  final difference = DateUtils.dateOnly(
    DateTime.now(),
  ).difference(DateUtils.dateOnly(value.toLocal()));
  final days = difference.inDays;

  if (days <= 0) {
    return 'Today';
  }
  if (days == 1) {
    return 'Yesterday';
  }

  return '$days days ago';
}

List<_FinanceMethodSummary> _buildMethodSummaries(
  List<GymTransactionSummary> transactions,
) {
  final map = <String, ({num amount, int count})>{};

  for (final transaction in transactions) {
    final method = (transaction.paymentMethod ?? 'unknown')
        .trim()
        .toLowerCase();
    final current = map[method];
    final nextAmount = (current?.amount ?? 0) + (transaction.amount ?? 0);
    final nextCount = (current?.count ?? 0) + 1;
    map[method] = (amount: nextAmount, count: nextCount);
  }

  final items = map.entries
      .map(
        (entry) => _FinanceMethodSummary(
          method: entry.key,
          amount: entry.value.amount,
          count: entry.value.count,
        ),
      )
      .toList(growable: false);

  items.sort((left, right) {
    final amountCompare = right.amount.abs().compareTo(left.amount.abs());
    if (amountCompare != 0) {
      return amountCompare;
    }

    return right.count.compareTo(left.count);
  });

  return items;
}

String _dateFilterLabel(_FinanceDateFilter filter) {
  return appDateRangeFilterLabel(filter);
}

String _dateFilterDescription(_FinanceDateFilter filter) {
  if (filter.preset == AppDateRangeFilterPreset.allTime) {
    return 'Showing the full finance ledger for the current gym.';
  }

  return 'Showing finance activity for ${formatAppDateRangeLong(filter.from, filter.to)}.';
}

String _emptyStateRangeMessage({
  required String prefix,
  required _FinanceDateFilter dateFilter,
}) {
  if (dateFilter.preset == AppDateRangeFilterPreset.allTime) {
    return '$prefix in the current ledger.';
  }

  return '$prefix for ${formatAppDateRangeLong(dateFilter.from, dateFilter.to)}.';
}

String _paymentMethodLabel(String method) {
  return switch (method.trim().toLowerCase()) {
    'cash' => 'Cash',
    'card' => 'Card',
    'terminal' => 'Terminal',
    'click' => 'Click',
    'payme' => 'Payme',
    'transfer' => 'Transfer',
    'debt' => 'Debt',
    'unknown' => 'Unknown',
    _ => _capitalizeWords(method.replaceAll('_', ' ')),
  };
}

String? _transactionTypeLabel(GymTransactionSummary transaction) {
  final badgeKey = _transactionBadgeKey(transaction);
  if (badgeKey == null ||
      _shouldHideFinanceBadgeValue(badgeKey) ||
      badgeKey == 'locker') {
    return null;
  }

  return switch (badgeKey) {
    'bar' => 'Bar',
    'package' => 'Package',
    'reversal' => 'Reversal',
    'entry' => 'Entry',
    _ => _capitalizeWords(badgeKey.replaceAll('_', ' ')),
  };
}

String? _transactionBadgeKey(GymTransactionSummary transaction) {
  final normalizedType = transaction.type?.trim().toLowerCase();
  final normalizedCategory = transaction.category?.trim().toLowerCase();

  if (normalizedType == 'payment') {
    return normalizedCategory == 'bar' ? 'bar' : 'package';
  }
  if (normalizedType == 'payment_reverse') {
    return 'reversal';
  }
  if (normalizedType == 'bar') {
    return 'bar';
  }
  if (normalizedCategory != null && normalizedCategory.isNotEmpty) {
    return normalizedCategory;
  }
  if (normalizedType != null && normalizedType.isNotEmpty) {
    return normalizedType;
  }

  return 'entry';
}

String? _transactionMethodLabel(GymTransactionSummary transaction) {
  final method = transaction.paymentMethod?.trim().toLowerCase();
  if (method == null || method.isEmpty) {
    return 'Unknown';
  }
  if (_shouldHideFinanceBadgeValue(method)) {
    return null;
  }

  return _paymentMethodLabel(method);
}

bool _isPackageStyleTransaction(GymTransactionSummary transaction) {
  final normalizedType = transaction.type?.trim().toLowerCase();
  final normalizedCategory = transaction.category?.trim().toLowerCase();

  return normalizedCategory == 'package' ||
      (normalizedType == 'payment' &&
          transaction.subscriptionId != null &&
          transaction.subscriptionId!.trim().isNotEmpty);
}

_FinanceTone _typeTone(GymTransactionSummary transaction) {
  final type = transaction.type?.trim().toLowerCase();
  if (type == 'bar') {
    return _FinanceTone.info;
  }
  if (type == 'payment_reverse') {
    return _FinanceTone.danger;
  }
  if (type == 'payment') {
    return _FinanceTone.success;
  }

  return _FinanceTone.subtle;
}

_FinanceTone _methodTone(String? value) {
  final method = value?.trim().toLowerCase();
  return switch (method) {
    'cash' => _FinanceTone.success,
    'card' => _FinanceTone.success,
    'terminal' => _FinanceTone.success,
    'click' => _FinanceTone.success,
    'payme' => _FinanceTone.success,
    'transfer' => _FinanceTone.success,
    'debt' => _FinanceTone.warning,
    _ => _FinanceTone.subtle,
  };
}

IconData? _transactionTypeIcon(GymTransactionSummary transaction) {
  final badgeKey = _transactionBadgeKey(transaction);
  if (badgeKey == null || _shouldHideFinanceBadgeValue(badgeKey)) {
    return null;
  }

  return switch (badgeKey) {
    'bar' => Icons.local_bar_rounded,
    'reversal' => Icons.reply_rounded,
    'package' => Icons.inventory_2_rounded,
    'locker' => Icons.key_rounded,
    _ => Icons.receipt_long_rounded,
  };
}

IconData? _paymentMethodIcon(String? value) {
  final method = value?.trim().toLowerCase();
  if (method == null ||
      method.isEmpty ||
      _shouldHideFinanceBadgeValue(method)) {
    return null;
  }

  return switch (method) {
    'cash' => Icons.payments_rounded,
    'card' => Icons.credit_card_rounded,
    'terminal' => Icons.point_of_sale_rounded,
    'click' => Icons.touch_app_rounded,
    'payme' => Icons.account_balance_wallet_rounded,
    'transfer' => Icons.swap_horiz_rounded,
    'debt' => Icons.warning_amber_rounded,
    _ => Icons.radio_button_checked_rounded,
  };
}

bool _shouldHideFinanceBadgeValue(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return true;
  }

  final lower = normalized.toLowerCase();
  if (lower == 'live') {
    return true;
  }

  return _looksLikeOpaqueFinanceId(normalized);
}

bool _looksLikeOpaqueFinanceId(String value) {
  final normalized = value.trim();
  if (normalized.length < 8) {
    return false;
  }
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalized)) {
    return false;
  }

  final hasUpper = normalized != normalized.toLowerCase();
  final hasLower = normalized != normalized.toUpperCase();
  final hasDigit = RegExp(r'\d').hasMatch(normalized);
  return hasUpper && hasLower && hasDigit;
}

Color _moneyColor(ThemeData theme, num value) {
  if (value > 0) {
    return AppColors.success;
  }
  if (value < 0) {
    return theme.colorScheme.error;
  }

  return AppColors.ink;
}

String _capitalizeWords(String value) {
  return value
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) => part.length == 1
            ? part.toUpperCase()
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);
