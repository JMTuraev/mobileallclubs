import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_currency.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../models/payment_amounts.dart';
import '../../clients/application/client_detail_providers.dart';
import '../../clients/domain/client_detail_models.dart';
import '../application/package_providers.dart';
import '../application/subscription_sale_service.dart';
import '../domain/gym_package_summary.dart';

class ActivatePackageRouteArgs {
  const ActivatePackageRouteArgs({
    required this.clientId,
    this.clientName,
    this.clientPhone,
    this.editSubscription,
    this.editStartOnly = false,
    this.popOnSuccess = false,
  });

  final String clientId;
  final String? clientName;
  final String? clientPhone;
  final ClientSubscriptionSummary? editSubscription;
  final bool editStartOnly;
  final bool popOnSuccess;
}

class ActivatePackageScreen extends ConsumerStatefulWidget {
  const ActivatePackageScreen({
    super.key,
    required this.clientId,
    this.clientName,
    this.clientPhone,
    this.editSubscription,
    this.editStartOnly = false,
    this.popOnSuccess = false,
  });

  final String clientId;
  final String? clientName;
  final String? clientPhone;
  final ClientSubscriptionSummary? editSubscription;
  final bool editStartOnly;
  final bool popOnSuccess;

  @override
  ConsumerState<ActivatePackageScreen> createState() =>
      _ActivatePackageScreenState();
}

class _ActivatePackageScreenState extends ConsumerState<ActivatePackageScreen> {
  final TextEditingController _cashController = TextEditingController(
    text: '0',
  );
  final TextEditingController _terminalController = TextEditingController(
    text: '0',
  );
  final TextEditingController _clickController = TextEditingController(
    text: '0',
  );
  final TextEditingController _debtController = TextEditingController(
    text: '0',
  );
  final TextEditingController _commentController = TextEditingController();

  DateTime _selectedDate = _defaultRequestDate();
  String? _selectedPackageId;
  String? _activeMethod;
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _isEditMode => widget.editStartOnly;

  bool get _isReplaceMode =>
      widget.editSubscription != null && !widget.editStartOnly;

  String get _title => switch ((_isEditMode, _isReplaceMode)) {
    (true, _) => 'Edit start date',
    (_, true) => 'Replace package',
    _ => 'Activate package',
  };

  String get _subtitle => switch ((_isEditMode, _isReplaceMode)) {
    (true, _) => 'Change only the subscription start date.',
    (_, true) => 'Select a new package for this client.',
    _ => 'Sell and activate a package for this client.',
  };

  @override
  void initState() {
    super.initState();
    final initialStart = widget.editSubscription?.startDate;
    if (initialStart != null) {
      _selectedDate = DateUtils.dateOnly(initialStart);
    }
  }

  @override
  void dispose() {
    _cashController.dispose();
    _terminalController.dispose();
    _clickController.dispose();
    _debtController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _selectPackage(String packageId) {
    setState(() {
      _selectedPackageId = packageId;
      _activeMethod = null;
      _statusMessage = null;
      _statusIsError = false;
      _resetPaymentInputs();
    });
  }

  void _resetPaymentInputs() {
    _cashController.text = '0';
    _terminalController.text = '0';
    _clickController.text = '0';
    _debtController.text = '0';
    _commentController.clear();
  }

  num _readAmount(TextEditingController controller) {
    return num.tryParse(controller.text.trim()) ?? 0;
  }

  TextEditingController _controllerFor(String method) {
    return switch (method) {
      'cash' => _cashController,
      'terminal' => _terminalController,
      'click' => _clickController,
      'debt' => _debtController,
      _ => _cashController,
    };
  }

  PaymentAmounts _paymentAmounts(num total) {
    return PaymentAmounts(
      cash: _readAmount(_cashController),
      terminal: _readAmount(_terminalController),
      click: _readAmount(_clickController),
      debt: _readAmount(_debtController),
      total: total,
    );
  }

  num _otherSum(String excludedMethod) {
    return {
          'cash': _readAmount(_cashController),
          'terminal': _readAmount(_terminalController),
          'click': _readAmount(_clickController),
          'debt': _readAmount(_debtController),
        }.entries
        .where((entry) => entry.key != excludedMethod)
        .fold<num>(0, (sum, entry) => sum + entry.value);
  }

  void _setAmount(String method, num value) {
    final normalized = value <= 0 ? '0' : _formatMoney(value);
    _controllerFor(method).text = normalized;
  }

  void _activateMethod(String method, num total) {
    if (_isSubmitting) {
      return;
    }

    setState(() => _activeMethod = method);

    final currentValue = _readAmount(_controllerFor(method));
    if (currentValue > 0) {
      return;
    }

    final allowed = total - _otherSum(method);
    _setAmount(method, allowed > 0 ? allowed : 0);
  }

  void _updateAmount(String method, String value, num total) {
    if (_isSubmitting) {
      return;
    }

    final numeric = num.tryParse(value.trim()) ?? 0;
    final allowed = total - _otherSum(method);
    final nextValue = numeric > allowed ? allowed : numeric;
    _setAmount(method, nextValue);
    setState(() {});
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() => _selectedDate = DateUtils.dateOnly(picked));
  }

  Future<void> _submitStartDateEdit({
    required ClientSubscriptionSummary subscription,
  }) async {
    if (_isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(subscriptionSaleServiceProvider)
          .updateSubscriptionStartDate(
            subscriptionId: subscription.id,
            newStartDate: _formatDateRequest(_selectedDate),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Subscription start date updated.';
        _statusIsError = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted) {
        return;
      }

      _handleSuccessNavigation();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = error.toString().replaceFirst('Exception: ', '');
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _handleSuccessNavigation() {
    if (widget.popOnSuccess && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }

    context.go(AppRoutes.clientDetail(widget.clientId));
  }

  Future<void> _submit({
    required GymClientDetail client,
    required GymPackageSummary package,
  }) async {
    if (_isSubmitting) {
      return;
    }

    final total = package.price?.toDouble() ?? 0;
    final amounts = _paymentAmounts(total);
    final needsComment =
        (amounts.usesDebt || _isReplaceMode) &&
        _commentController.text.trim().isEmpty;

    if (_activeMethod == null) {
      setState(() {
        _statusMessage = 'Choose a payment method first.';
        _statusIsError = true;
      });
      return;
    }

    if (!amounts.isBalanced) {
      setState(() {
        _statusMessage =
            'Payment must fully cover the package total before activation.';
        _statusIsError = true;
      });
      return;
    }

    if (needsComment) {
      setState(() {
        _statusMessage = amounts.usesDebt
            ? 'Debt payments require a comment.'
            : 'Replacement requires a comment.';
        _statusIsError = true;
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(subscriptionSaleServiceProvider)
          .createSubscription(
            clientId: client.id,
            packageId: package.id,
            startDate: _formatDateRequest(_selectedDate),
            amounts: amounts,
            comment: _commentController.text,
            replaceId: widget.editSubscription?.id,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = _isReplaceMode
            ? '${package.name ?? 'Package'} replaced for ${client.fullName}.'
            : '${package.name ?? 'Package'} activated for ${client.fullName}.';
        _statusIsError = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted) {
        return;
      }

      _handleSuccessNavigation();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = error.toString().replaceFirst('Exception: ', '');
        _statusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _resolveClientName(GymClientDetail? client) {
    if (client != null) {
      return client.fullName;
    }

    if (widget.clientName != null && widget.clientName!.trim().isNotEmpty) {
      return widget.clientName!.trim();
    }

    return 'Client';
  }

  String? _resolveClientPhone(GymClientDetail? client) {
    return client?.phone ?? widget.clientPhone;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    final clientAsync = ref.watch(
      currentGymClientDocumentProvider(widget.clientId),
    );
    final packagesAsync = ref.watch(currentGymPackagesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (widget.popOnSuccess && Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
              return;
            }

            context.go(AppRoutes.clientDetail(widget.clientId));
          },
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: widget.popOnSuccess ? 'Back' : 'Back to client',
        ),
        title: Text(_title),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: clientAsync.when(
                  loading: () => const _SaleLoadingCard(
                    title: 'Client',
                    message: 'Loading client...',
                  ),
                  error: (error, stackTrace) => _SaleErrorCard(
                    title: 'Client unavailable',
                    message: error.toString(),
                  ),
                  data: (client) {
                    final effectiveClient =
                        client ??
                        GymClientDetail(
                          id: widget.clientId,
                          firstName: widget.clientName,
                          phone: widget.clientPhone,
                        );

                    return packagesAsync.when(
                      loading: () => const _SaleLoadingCard(
                        title: 'Packages',
                        message: 'Loading packages...',
                      ),
                      error: (error, stackTrace) => _SaleErrorCard(
                        title: 'Packages unavailable',
                        message: error.toString(),
                      ),
                      data: (packages) {
                        GymPackageSummary? selectedPackage;
                        for (final package in packages) {
                          if (package.id == _selectedPackageId) {
                            selectedPackage = package;
                            break;
                          }
                        }
                        final total = selectedPackage?.price?.toDouble() ?? 0;
                        final paymentAmounts = _paymentAmounts(total);
                        final resolvedName = _resolveClientName(client);
                        final resolvedPhone = _resolveClientPhone(client);

                        return ListView(
                          children: [
                            _SaleModeCard(title: _title, subtitle: _subtitle),
                            const SizedBox(height: 12),
                            _ClientSaleCard(
                              clientName: resolvedName,
                              clientPhone: resolvedPhone,
                              clientId: widget.clientId,
                            ),
                            const SizedBox(height: 12),
                            if (_isEditMode) ...[
                              _SaleDateCard(
                                selectedDate: _selectedDate,
                                onPickDate: _isSubmitting
                                    ? null
                                    : _pickStartDate,
                                title: 'New start date',
                              ),
                            ] else ...[
                              if (!_isReplaceMode)
                                _SaleDateCard(
                                  selectedDate: _selectedDate,
                                  onPickDate: _isSubmitting
                                      ? null
                                      : _pickStartDate,
                                ),
                              const SizedBox(height: 12),
                              if (packages.isEmpty)
                                const _SaleErrorCard(
                                  title: 'No packages found',
                                  message: 'Create a package first.',
                                )
                              else
                                _PackagePickerCard(
                                  packages: packages,
                                  selectedPackageId: _selectedPackageId,
                                  disabledPackageId: _isReplaceMode
                                      ? widget.editSubscription?.packageId
                                      : null,
                                  onSelectPackage: _isSubmitting
                                      ? null
                                      : _selectPackage,
                                ),
                            ],
                            if (_isEditMode && widget.editSubscription == null)
                              const _SaleErrorCard(
                                title: 'Subscription unavailable',
                                message: 'Subscription data is missing.',
                              ),
                            if (selectedPackage != null) ...[
                              const SizedBox(height: 12),
                              _PaymentEditorCard(
                                activeMethod: _activeMethod,
                                cashController: _cashController,
                                clickController: _clickController,
                                commentController: _commentController,
                                debtController: _debtController,
                                isSubmitting: _isSubmitting,
                                paymentAmounts: paymentAmounts,
                                selectedPackage: selectedPackage,
                                terminalController: _terminalController,
                                onActivateMethod: _activateMethod,
                                requireComment: _isReplaceMode,
                                onQuickAmount: (amount) {
                                  final method = _activeMethod ?? 'cash';
                                  _activateMethod(method, total);
                                  _updateAmount(
                                    method,
                                    amount.toString(),
                                    total,
                                  );
                                },
                                onUpdateAmount: (method, value) =>
                                    _updateAmount(method, value, total),
                              ),
                            ],
                            if (_statusMessage != null) ...[
                              const SizedBox(height: 12),
                              _SaleStatusCard(
                                message: _statusMessage!,
                                isError: _statusIsError,
                              ),
                            ],
                            if (_isEditMode &&
                                widget.editSubscription != null) ...[
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _submitStartDateEdit(
                                        subscription: widget.editSubscription!,
                                      ),
                                icon: const Icon(Icons.save_rounded),
                                label: Text(
                                  _isSubmitting ? 'Saving...' : 'Save',
                                ),
                              ),
                            ],
                            if (!_isEditMode && selectedPackage != null) ...[
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _submit(
                                        client: effectiveClient,
                                        package: selectedPackage!,
                                      ),
                                icon: const Icon(Icons.check_circle_rounded),
                                label: Text(
                                  _isSubmitting
                                      ? (_isReplaceMode
                                            ? 'Replacing package...'
                                            : 'Activating package...')
                                      : (_isReplaceMode
                                            ? 'Replace package'
                                            : 'Sell package'),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaleModeCard extends StatelessWidget {
  const _SaleModeCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF7D74FF).withValues(alpha: 0.2),
              const Color(0xFF5149E8).withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.84)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ClientSaleCard extends StatelessWidget {
  const _ClientSaleCard({
    required this.clientName,
    required this.clientPhone,
    required this.clientId,
  });

  final String clientName;
  final String? clientPhone;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(clientName, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (clientPhone != null)
              Text(clientPhone!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text('ID $clientId', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SaleDateCard extends StatelessWidget {
  const _SaleDateCard({
    required this.selectedDate,
    required this.onPickDate,
    this.title = 'Start date',
  });

  final DateTime selectedDate;
  final VoidCallback? onPickDate;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: Text(_formatDateRequest(selectedDate)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagePickerCard extends StatelessWidget {
  const _PackagePickerCard({
    required this.packages,
    required this.selectedPackageId,
    required this.onSelectPackage,
    this.disabledPackageId,
  });

  final List<GymPackageSummary> packages;
  final String? selectedPackageId;
  final ValueChanged<String>? onSelectPackage;
  final String? disabledPackageId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Packages', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ...packages.map(
              (package) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PackageTile(
                  package: package,
                  isSelected: package.id == selectedPackageId,
                  isDisabled: package.id == disabledPackageId,
                  onTap: onSelectPackage == null
                      ? null
                      : () => onSelectPackage!(package.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.package,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  final GymPackageSummary package;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = isSelected
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final foregroundColor = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;
    final borderColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;

    return OutlinedButton(
      onPressed: isDisabled ? null : onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  package.name ?? 'Unnamed package',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDisabled
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                        : foregroundColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isSelected && !isDisabled) ...[
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                package.price == null
                    ? '-'
                    : _formatMoney(package.price!, withUnit: true),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                      : theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(
                icon: Icons.date_range_rounded,
                label: package.duration == null
                    ? 'Duration -'
                    : '${package.duration} days',
              ),
              _MiniChip(
                icon: Icons.repeat_rounded,
                label: package.isUnlimited == true
                    ? 'Unlimited visits'
                    : package.effectiveVisitLimit == null
                    ? 'Visits -'
                    : '${package.effectiveVisitLimit} visits',
              ),
              if ((package.bonusDays ?? 0) > 0)
                _MiniChip(
                  icon: Icons.add_circle_outline_rounded,
                  label: '+${package.bonusDays} bonus days',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentEditorCard extends StatelessWidget {
  const _PaymentEditorCard({
    required this.activeMethod,
    required this.cashController,
    required this.clickController,
    required this.commentController,
    required this.debtController,
    required this.isSubmitting,
    required this.paymentAmounts,
    required this.selectedPackage,
    required this.terminalController,
    required this.onActivateMethod,
    required this.requireComment,
    required this.onQuickAmount,
    required this.onUpdateAmount,
  });

  final String? activeMethod;
  final TextEditingController cashController;
  final TextEditingController clickController;
  final TextEditingController commentController;
  final TextEditingController debtController;
  final bool isSubmitting;
  final PaymentAmounts paymentAmounts;
  final GymPackageSummary selectedPackage;
  final TextEditingController terminalController;
  final void Function(String method, num total) onActivateMethod;
  final bool requireComment;
  final ValueChanged<num> onQuickAmount;
  final void Function(String method, String value) onUpdateAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = selectedPackage.price?.toDouble() ?? 0;
    final needsComment =
        (paymentAmounts.usesDebt || requireComment) &&
        commentController.text.trim().isEmpty;
    final methods = [
      (
        key: 'cash',
        label: 'Cash',
        icon: Icons.payments_rounded,
        controller: cashController,
      ),
      (
        key: 'terminal',
        label: 'Terminal',
        icon: Icons.credit_card_rounded,
        controller: terminalController,
      ),
      (
        key: 'click',
        label: 'Click',
        icon: Icons.phone_android_rounded,
        controller: clickController,
      ),
      (
        key: 'debt',
        label: 'Debt',
        icon: Icons.warning_amber_rounded,
        controller: debtController,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _MetricLine(
              label: 'Package total',
              value: _formatMoney(total, withUnit: true),
            ),
            _MetricLine(
              label: 'Paid',
              value: _formatMoney(paymentAmounts.paidTotal, withUnit: true),
            ),
            _MetricLine(
              label: 'Remaining',
              value: _formatMoney(paymentAmounts.remaining, withUnit: true),
              tone: paymentAmounts.remaining.abs() < 0.01
                  ? _LineTone.success
                  : _LineTone.error,
            ),
            const SizedBox(height: 16),
            ...methods.map(
              (method) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: FilledButton.tonalIcon(
                        onPressed: isSubmitting
                            ? null
                            : () => onActivateMethod(method.key, total),
                        icon: Icon(method.icon),
                        label: Text(method.label),
                        style: FilledButton.styleFrom(
                          backgroundColor: activeMethod == method.key
                              ? theme.colorScheme.primaryContainer
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: method.controller,
                        enabled: activeMethod == method.key && !isSubmitting,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (value) => onUpdateAmount(method.key, value),
                        decoration: InputDecoration(
                          labelText: method.label,
                          hintText: '0',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: isSubmitting ? null : () => onQuickAmount(50000),
                  child: const Text('+50k'),
                ),
                OutlinedButton(
                  onPressed: isSubmitting ? null : () => onQuickAmount(100000),
                  child: const Text('+100k'),
                ),
                FilledButton.tonal(
                  onPressed: isSubmitting ? null : () => onQuickAmount(total),
                  child: const Text('Full'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              enabled: !isSubmitting,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: needsComment ? 'Comment required' : 'Comment',
                hintText: paymentAmounts.usesDebt
                    ? 'Debt note'
                    : requireComment
                    ? 'Replacement reason'
                    : 'Optional note',
                errorText: needsComment
                    ? paymentAmounts.usesDebt
                          ? 'Debt payments require a comment.'
                          : 'Replacement requires a comment.'
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleStatusCard extends StatelessWidget {
  const _SaleStatusCard({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isError
          ? AppColors.danger.withValues(alpha: 0.18)
          : AppColors.success.withValues(alpha: 0.16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isError ? AppColors.danger : AppColors.success,
          ),
        ),
      ),
    );
  }
}

class _SaleLoadingCard extends StatelessWidget {
  const _SaleLoadingCard({required this.title, required this.message});

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

class _SaleErrorCard extends StatelessWidget {
  const _SaleErrorCard({required this.title, required this.message});

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
            const SizedBox(height: 10),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({
    required this.label,
    required this.value,
    this.tone = _LineTone.defaultTone,
  });

  final String label;
  final String value;
  final _LineTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      _LineTone.success => Colors.green.shade600,
      _LineTone.error => theme.colorScheme.error,
      _LineTone.defaultTone => theme.colorScheme.onSurface,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

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

enum _LineTone { defaultTone, success, error }

String _formatDateRequest(DateTime value) {
  final normalized = DateUtils.dateOnly(value);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

DateTime _defaultRequestDate() {
  final nowUtc = DateTime.now().toUtc();
  return DateTime(nowUtc.year, nowUtc.month, nowUtc.day);
}

String _formatMoney(num value, {bool withUnit = false}) {
  return formatAppMoney(value, withUnit: withUnit);
}
