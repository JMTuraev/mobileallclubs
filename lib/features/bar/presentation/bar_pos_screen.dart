import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../../models/payment_amounts.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../clients/application/client_detail_providers.dart';
import '../../clients/domain/client_detail_models.dart';
import '../application/bar_actions_service.dart';
import '../application/bar_providers.dart';
import '../domain/bar_category_summary.dart';
import '../domain/bar_check_item.dart';
import '../domain/bar_product_summary.dart';
import '../domain/bar_session_check_summary.dart';

class BarPosScreen extends ConsumerStatefulWidget {
  const BarPosScreen({
    super.key,
    this.clientId,
    this.sessionId,
    this.isGuestMode = false,
  });

  final String? clientId;
  final String? sessionId;
  final bool isGuestMode;

  @override
  ConsumerState<BarPosScreen> createState() => _BarPosScreenState();
}

class _BarPosScreenState extends ConsumerState<BarPosScreen> {
  String? _selectedCategoryId;
  String? _activeCheckId;
  String? _statusMessage;
  bool _statusIsError = false;
  bool _isLoadingDraft = true;
  bool _isPaying = false;
  bool _isCheckingDebt = false;
  final Set<String> _busyProductIds = <String>{};
  final Set<String> _busyCheckIds = <String>{};
  BarClientDebtSnapshot? _latestDebtSnapshot;

  @override
  void initState() {
    super.initState();
    unawaited(_loadExistingDraftCheck());
  }

  Future<void> _loadExistingDraftCheck() async {
    if (widget.isGuestMode) {
      if (mounted) {
        setState(() => _isLoadingDraft = false);
      }
      return;
    }

    try {
      final sessionId = widget.sessionId?.trim() ?? '';
      if (sessionId.isEmpty) {
        if (mounted) {
          setState(() => _isLoadingDraft = false);
        }
        return;
      }

      final checkId = await ref
          .read(barActionsServiceProvider)
          .findDraftCheckId(sessionId: sessionId);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCheckId = checkId;
      });
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
        setState(() => _isLoadingDraft = false);
      }
    }
  }

  void _setStatus(String message, {required bool isError}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<void> _addProduct(BarProductSummary product) async {
    if (_busyProductIds.contains(product.id) || _isPaying) {
      return;
    }

    setState(() {
      _busyProductIds.add(product.id);
    });

    try {
      final service = ref.read(barActionsServiceProvider);
      final checkId =
          _activeCheckId ??
          await service.getOrCreateOpenCheck(
            clientId: widget.clientId,
            sessionId: widget.sessionId,
          );

      if (checkId == null || checkId.isEmpty) {
        throw Exception('Unable to create or resolve the current bar check.');
      }

      await service.addItemToCheck(checkId: checkId, productId: product.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCheckId = checkId;
        _statusMessage = '${product.name} added to the active check.';
        _statusIsError = false;
      });
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
          _busyProductIds.remove(product.id);
        });
      }
    }
  }

  Future<void> _increaseItem(BarCheckItem item) async {
    if (_activeCheckId == null || item.productId == null || _isPaying) {
      return;
    }

    try {
      await ref
          .read(barActionsServiceProvider)
          .addItemToCheck(checkId: _activeCheckId!, productId: item.productId!);

      if (!mounted) {
        return;
      }

      _setStatus('${item.displayName} quantity increased.', isError: false);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _removeItem(BarCheckItem item) async {
    if (_activeCheckId == null || item.productId == null || _isPaying) {
      return;
    }

    try {
      await ref
          .read(barActionsServiceProvider)
          .removeItemFromCheck(
            checkId: _activeCheckId!,
            productId: item.productId!,
          );

      if (!mounted) {
        return;
      }

      _setStatus(
        '${item.displayName} updated in the active check.',
        isError: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _voidCheck() async {
    final checkId = _activeCheckId;
    if (checkId == null || checkId.isEmpty || _isPaying) {
      return;
    }

    try {
      await ref.read(barActionsServiceProvider).voidCheck(checkId: checkId);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCheckId = null;
      });
      _setStatus('The active draft check was voided.', isError: false);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _holdCheck() async {
    final checkId = _activeCheckId;
    if (checkId == null || checkId.isEmpty || _isPaying) {
      return;
    }

    try {
      await ref.read(barActionsServiceProvider).holdCheck(checkId: checkId);

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCheckId = null;
      });
      _setStatus(
        'The current draft check was saved for later.',
        isError: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    }
  }

  Future<void> _payCheck(num total) async {
    final checkId = _activeCheckId;
    if (checkId == null || checkId.isEmpty || total <= 0 || _isPaying) {
      return;
    }

    final amounts = await showDialog<PaymentAmounts>(
      context: context,
      builder: (context) => _BarPaymentDialog(total: total),
    );

    if (amounts == null) {
      return;
    }

    setState(() => _isPaying = true);

    try {
      await ref
          .read(barActionsServiceProvider)
          .payCheck(checkId: checkId, methods: amounts.toJson());

      if (!mounted) {
        return;
      }

      setState(() {
        _activeCheckId = null;
        _statusMessage = 'Bar check paid successfully.';
        _statusIsError = false;
      });
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
        setState(() => _isPaying = false);
      }
    }
  }

  Future<void> _checkClientDebt() async {
    final clientId = widget.clientId?.trim() ?? '';
    if (widget.isGuestMode || _isCheckingDebt || _isPaying || clientId.isEmpty) {
      return;
    }

    setState(() => _isCheckingDebt = true);

    try {
      final debtSnapshot = await ref
          .read(barActionsServiceProvider)
          .checkClientDebt(clientId: clientId);

      if (!mounted) {
        return;
      }

      setState(() {
        _latestDebtSnapshot = debtSnapshot;
        _statusMessage = debtSnapshot.totalDebt > 0
            ? 'Client debt refreshed. Total debt: ${_formatMoney(debtSnapshot.totalDebt)} so\'m.'
            : 'Client debt refreshed. No unpaid draft or held checks were returned.';
        _statusIsError = false;
      });
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
        setState(() => _isCheckingDebt = false);
      }
    }
  }

  Future<void> _refundCheck(BarSessionCheckSummary check) async {
    if (_busyCheckIds.contains(check.id) || _isPaying) {
      return;
    }

    final shouldRefund = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refund bar check'),
        content: Text(
          'Refund paid check ${check.id}? This uses the exact refundCheck callable from the working backend.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Refund'),
          ),
        ],
      ),
    );

    if (shouldRefund != true || !mounted) {
      return;
    }

    setState(() {
      _busyCheckIds.add(check.id);
    });

    try {
      await ref.read(barActionsServiceProvider).refundCheck(checkId: check.id);

      if (!mounted) {
        return;
      }

      _setStatus('Paid check ${check.id} refunded.', isError: false);
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
          _busyCheckIds.remove(check.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resolvedSession = ref.watch(bootstrapControllerProvider).session;
    final categoriesAsync = ref.watch(currentGymBarCategoriesProvider);
    final productsAsync = ref.watch(currentGymBarProductsProvider);
    final checkItemsAsync = _activeCheckId == null
        ? const AsyncValue<List<BarCheckItem>>.data(<BarCheckItem>[])
        : ref.watch(barCheckItemsProvider(_activeCheckId!));
    final clientAsync = widget.isGuestMode
        ? const AsyncValue<GymClientDetail?>.data(
            GymClientDetail(id: 'guest', firstName: 'Guest'),
          )
        : ref.watch(
            currentGymClientDocumentProvider(widget.clientId?.trim() ?? ''),
          );
    final sessionChecksAsync = widget.isGuestMode
        ? const AsyncValue<List<BarSessionCheckSummary>>.data(
            <BarSessionCheckSummary>[],
          )
        : ref.watch(barSessionChecksProvider(widget.sessionId?.trim() ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('Bar POS')),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AppShellBody(
            maxWidth: 760,
            child: clientAsync.when(
              loading: () => const _BarLoadingCard(
                title: 'Client',
                message: 'Loading current client for bar POS...',
              ),
              error: (error, stackTrace) => _BarStatusCard(
                title: 'Client unavailable',
                message: error.toString(),
                isError: true,
              ),
              data: (client) {
                try {
                  if (client == null) {
                    return const _BarStatusCard(
                      title: 'Client unavailable',
                      message:
                          'The client document could not be resolved in the current gym.',
                      isError: true,
                    );
                  }

                  if (categoriesAsync.isLoading ||
                      productsAsync.isLoading ||
                      _isLoadingDraft) {
                    return const _BarLoadingCard(
                      title: 'Bar POS',
                      message:
                          'Loading categories, products, and draft checks...',
                    );
                  }

                  if (categoriesAsync.hasError) {
                    return _BarStatusCard(
                      title: 'Categories unavailable',
                      message: categoriesAsync.error.toString(),
                      isError: true,
                    );
                  }

                  if (productsAsync.hasError) {
                    return _BarStatusCard(
                      title: 'Products unavailable',
                      message: productsAsync.error.toString(),
                      isError: true,
                    );
                  }

                  final categories =
                      categoriesAsync.value ?? const <BarCategorySummary>[];
                  final products =
                      productsAsync.value ?? const <BarProductSummary>[];

                  final selectedCategoryIdForView =
                      _selectedCategoryId != null &&
                          categories.any(
                            (category) => category.id == _selectedCategoryId,
                          )
                      ? _selectedCategoryId
                      : categories.isNotEmpty
                      ? categories.first.id
                      : null;

                  final filteredProducts = selectedCategoryIdForView == null
                      ? products
                      : products
                            .where(
                              (product) =>
                                  product.categoryId ==
                                  selectedCategoryIdForView,
                            )
                            .toList(growable: false);
                  final checkItems =
                      checkItemsAsync.value ?? const <BarCheckItem>[];
                  final total = checkItems.fold<num>(
                    0,
                    (sum, item) => sum + item.total,
                  );
                  final canRefundPaidChecks =
                      resolvedSession?.role == AllClubsRole.owner;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _BarClientCard(
                          clientName: widget.isGuestMode
                              ? 'Guest'
                              : client.fullName,
                          phone: client.phone,
                          sessionId: widget.sessionId,
                          activeCheckId: _activeCheckId,
                          isGuestMode: widget.isGuestMode,
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          _BarStatusCard(
                            title: _statusIsError
                                ? 'Bar action failed'
                                : 'Bar POS',
                            message: _statusMessage!,
                            isError: _statusIsError,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _BarCategoriesCard(
                          categories: categories,
                          selectedCategoryId: selectedCategoryIdForView,
                          onSelect: (categoryId) {
                            setState(() {
                              _selectedCategoryId = categoryId;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _BarProductsCard(
                          products: filteredProducts,
                          busyProductIds: _busyProductIds,
                          onAdd: _addProduct,
                        ),
                        const SizedBox(height: 12),
                        _BarCartCard(
                          checkItems: checkItems,
                          total: total,
                          isBusy: _isPaying,
                          activeCheckId: _activeCheckId,
                          onIncrease: _increaseItem,
                          onRemove: _removeItem,
                          onHold: _holdCheck,
                          onVoid: _voidCheck,
                          onPay: () => _payCheck(total),
                        ),
                        const SizedBox(height: 12),
                        if (!widget.isGuestMode) ...[
                          _BarDebtCard(
                            debtSnapshot: _latestDebtSnapshot,
                            isChecking: _isCheckingDebt,
                            onCheckDebt: _checkClientDebt,
                          ),
                          const SizedBox(height: 12),
                          sessionChecksAsync.when(
                            loading: () => const _BarLoadingCard(
                              title: 'Check history',
                              message:
                                  'Loading session-linked bar checks from gyms/{gymId}/barChecks...',
                            ),
                            error: (error, stackTrace) => _BarStatusCard(
                              title: 'Check history unavailable',
                              message: error.toString(),
                              isError: true,
                            ),
                            data: (checks) => _BarSessionChecksCard(
                              checks: checks,
                              canRefundPaidChecks: canRefundPaidChecks,
                              busyCheckIds: _busyCheckIds,
                              onRefund: _refundCheck,
                            ),
                          ),
                        ] else ...[
                          _BarStatusCard(
                            title: 'Guest POS',
                            message:
                                'Guest mode follows the web contract: createCheck with null clientId and null sessionId. Client debt and session-linked history do not apply here.',
                            isError: false,
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                } catch (error, stackTrace) {
                  debugPrint('[BarPosScreen] build failure: $error');
                  debugPrintStack(
                    label: '[BarPosScreen] build stack',
                    stackTrace: stackTrace,
                  );
                  return _BarStatusCard(
                    title: 'Bar POS build failed',
                    message: error.toString(),
                    isError: true,
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BarClientCard extends StatelessWidget {
  const _BarClientCard({
    required this.clientName,
    required this.phone,
    required this.sessionId,
    required this.activeCheckId,
    required this.isGuestMode,
  });

  final String clientName;
  final String? phone;
  final String? sessionId;
  final String? activeCheckId;
  final bool isGuestMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGuestMode ? 'Guest POS' : 'Current session',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(clientName, style: theme.textTheme.headlineSmall),
            if (phone != null) ...[
              const SizedBox(height: 8),
              Text(phone!, style: theme.textTheme.bodyLarge),
            ],
            if (isGuestMode) ...[
              const SizedBox(height: 8),
              Text(
                'Guest checks are created without a linked client or session, matching the web POS flow.',
                style: theme.textTheme.bodyMedium,
              ),
            ] else if (sessionId != null && sessionId!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Session ID $sessionId',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (activeCheckId != null && activeCheckId!.trim().isNotEmpty)
              Text(
                'Draft check $activeCheckId',
                style: theme.textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _BarCategoriesCard extends StatelessWidget {
  const _BarCategoriesCard({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelect,
  });

  final List<BarCategorySummary> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categories', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              Text(
                'No active bar categories were returned from the current gym.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories
                    .map(
                      (category) => ChoiceChip(
                        label: Text(category.name),
                        selected: category.id == selectedCategoryId,
                        onSelected: (_) => onSelect(category.id),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarProductsCard extends StatelessWidget {
  const _BarProductsCard({
    required this.products,
    required this.busyProductIds,
    required this.onAdd,
  });

  final List<BarProductSummary> products;
  final Set<String> busyProductIds;
  final ValueChanged<BarProductSummary> onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Products', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (products.isEmpty)
              Text(
                'No active products matched the selected bar category.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...products.map((product) {
                final isBusy = busyProductIds.contains(product.id);
                final isOutOfStock = product.availableStock <= 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_formatMoney(product.price ?? 0)} so\'m',
                                style: theme.textTheme.bodyLarge,
                              ),
                              Text(
                                'Stock ${product.availableStock}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 108,
                          child: FilledButton.tonal(
                            onPressed: isBusy || isOutOfStock
                                ? null
                                : () => onAdd(product),
                            child: Text(isBusy ? 'Adding...' : 'Add'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _BarCartCard extends StatelessWidget {
  const _BarCartCard({
    required this.checkItems,
    required this.total,
    required this.isBusy,
    required this.activeCheckId,
    required this.onIncrease,
    required this.onRemove,
    required this.onHold,
    required this.onVoid,
    required this.onPay,
  });

  final List<BarCheckItem> checkItems;
  final num total;
  final bool isBusy;
  final String? activeCheckId;
  final ValueChanged<BarCheckItem> onIncrease;
  final ValueChanged<BarCheckItem> onRemove;
  final VoidCallback onHold;
  final VoidCallback onVoid;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current check', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (checkItems.isEmpty)
              Text(
                activeCheckId == null
                    ? 'No draft bar check is open for this session yet.'
                    : 'The current draft check is empty.',
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              ...checkItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.displayName,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_formatMoney(item.unitPrice)} so\'m × ${item.quantity}',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 52,
                              child: FilledButton.tonal(
                                onPressed: isBusy
                                    ? null
                                    : () => onIncrease(item),
                                child: const Text('+'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 52,
                              child: FilledButton.tonal(
                                onPressed: isBusy ? null : () => onRemove(item),
                                child: const Text('−'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text('Total', style: theme.textTheme.titleMedium),
                  ),
                  Text(
                    '${_formatMoney(total)} so\'m',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: isBusy ? null : onPay,
                    icon: const Icon(Icons.payments_rounded),
                    label: Text(isBusy ? 'Paying...' : 'Pay check'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: isBusy ? null : onHold,
                    icon: const Icon(Icons.pause_circle_outline_rounded),
                    label: const Text('Hold check'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: isBusy ? null : onVoid,
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Void draft'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BarDebtCard extends StatelessWidget {
  const _BarDebtCard({
    required this.debtSnapshot,
    required this.isChecking,
    required this.onCheckDebt,
  });

  final BarClientDebtSnapshot? debtSnapshot;
  final bool isChecking;
  final VoidCallback onCheckDebt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client debt', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              debtSnapshot == null
                  ? 'Run the exact checkClientDebt callable to inspect unpaid draft or held checks for this client.'
                  : 'Total debt ${_formatMoney(debtSnapshot!.totalDebt)} so\'m across ${debtSnapshot!.unpaidChecks.length} unpaid checks.',
              style: theme.textTheme.bodyLarge,
            ),
            if (debtSnapshot != null &&
                debtSnapshot!.unpaidChecks.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...debtSnapshot!.unpaidChecks.map(
                (check) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check ${check.id}',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Status ${check.status ?? 'unknown'}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          'Debt ${_formatMoney(check.debtAmount ?? check.totalAmount ?? 0)} so\'m',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: isChecking ? null : onCheckDebt,
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(isChecking ? 'Checking...' : 'Check debt'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarSessionChecksCard extends StatelessWidget {
  const _BarSessionChecksCard({
    required this.checks,
    required this.canRefundPaidChecks,
    required this.busyCheckIds,
    required this.onRefund,
  });

  final List<BarSessionCheckSummary> checks;
  final bool canRefundPaidChecks;
  final Set<String> busyCheckIds;
  final ValueChanged<BarSessionCheckSummary> onRefund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Check history', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            if (checks.isEmpty)
              Text(
                'No bar checks were returned for this session yet.',
                style: theme.textTheme.bodyLarge,
              )
            else
              ...checks.map(
                (check) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Check ${check.id}',
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              check.displayStatus,
                              style: theme.textTheme.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total ${_formatMoney(check.totalAmount ?? 0)} so\'m',
                          style: theme.textTheme.bodyLarge,
                        ),
                        Text(
                          'Paid ${_formatMoney(check.paidAmount ?? 0)} so\'m',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          'Debt ${_formatMoney(check.debtAmount ?? 0)} so\'m',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (check.itemCount != null)
                          Text(
                            '${check.itemCount} items',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (check.createdAt != null)
                          Text(
                            'Created ${_formatDateTime(check.createdAt)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        if (canRefundPaidChecks && check.isPaid) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.tonalIcon(
                              onPressed: busyCheckIds.contains(check.id)
                                  ? null
                                  : () => onRefund(check),
                              icon: const Icon(Icons.undo_rounded),
                              label: Text(
                                busyCheckIds.contains(check.id)
                                    ? 'Refunding...'
                                    : 'Refund paid check',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarPaymentDialog extends StatefulWidget {
  const _BarPaymentDialog({required this.total});

  final num total;

  @override
  State<_BarPaymentDialog> createState() => _BarPaymentDialogState();
}

class _BarPaymentDialogState extends State<_BarPaymentDialog> {
  late final TextEditingController _cashController;
  late final TextEditingController _terminalController;
  late final TextEditingController _clickController;
  late final TextEditingController _debtController;

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(text: _formatMoney(widget.total));
    _terminalController = TextEditingController(text: '0');
    _clickController = TextEditingController(text: '0');
    _debtController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    _cashController.dispose();
    _terminalController.dispose();
    _clickController.dispose();
    _debtController.dispose();
    super.dispose();
  }

  PaymentAmounts get _amounts => PaymentAmounts(
    cash: _readAmount(_cashController),
    terminal: _readAmount(_terminalController),
    click: _readAmount(_clickController),
    debt: _readAmount(_debtController),
    total: widget.total,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amounts = _amounts;

    return AlertDialog(
      title: const Text('Pay bar check'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total ${_formatMoney(widget.total)} so\'m',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining ${_formatMoney(amounts.remaining)} so\'m',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: amounts.isBalanced
                    ? Colors.green.shade600
                    : theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            _PaymentField(
              controller: _cashController,
              label: 'Cash',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _PaymentField(
              controller: _terminalController,
              label: 'Terminal',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _PaymentField(
              controller: _clickController,
              label: 'Click',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            _PaymentField(
              controller: _debtController,
              label: 'Debt',
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: amounts.isBalanced
              ? () => Navigator.of(context).pop(amounts)
              : null,
          child: const Text('Confirm payment'),
        ),
      ],
    );
  }
}

class _PaymentField extends StatelessWidget {
  const _PaymentField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: '0'),
    );
  }
}

class _BarLoadingCard extends StatelessWidget {
  const _BarLoadingCard({required this.title, required this.message});

  final String title;
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
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _BarStatusCard extends StatelessWidget {
  const _BarStatusCard({
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

num _readAmount(TextEditingController controller) {
  return num.tryParse(controller.text.trim()) ?? 0;
}

String _formatMoney(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2);
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '-';
  }

  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
