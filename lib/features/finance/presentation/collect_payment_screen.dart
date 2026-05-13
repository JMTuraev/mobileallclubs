import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_currency.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_route_back_scope.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../models/payment_amounts.dart';
import '../../clients/application/client_detail_providers.dart';
import '../../clients/domain/client_detail_models.dart';
import '../application/payment_actions_service.dart';
import '../application/transaction_providers.dart';
import '../domain/client_finance_resolution.dart';

class CollectPaymentScreen extends ConsumerStatefulWidget {
  const CollectPaymentScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<CollectPaymentScreen> createState() =>
      _CollectPaymentScreenState();
}

class _CollectPaymentScreenState extends ConsumerState<CollectPaymentScreen> {
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

  String? _activeMethod;
  bool _isSubmitting = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  void dispose() {
    _cashController.dispose();
    _terminalController.dispose();
    _clickController.dispose();
    _debtController.dispose();
    _commentController.dispose();
    super.dispose();
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
    final normalized = value <= 0 ? '0' : _formatAmount(value);
    _controllerFor(method).text = normalized;
  }

  void _activateMethod(String method, num total) {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _activeMethod = method;
      _statusMessage = null;
      _statusIsError = false;
    });

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

  Future<void> _submit({
    required GymClientDetail client,
    required ClientSubscriptionSummary subscription,
    required num total,
  }) async {
    if (_isSubmitting) {
      return;
    }

    final amounts = _paymentAmounts(total);
    final needsComment =
        amounts.usesDebt && _commentController.text.trim().isEmpty;

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
            'Payment must fully cover the remaining amount before confirmation.';
        _statusIsError = true;
      });
      return;
    }

    if (needsComment) {
      setState(() {
        _statusMessage = 'Debt payments require a comment.';
        _statusIsError = true;
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(paymentActionsServiceProvider)
          .collectPayment(
            clientId: client.id,
            subscription: subscription,
            amounts: amounts,
            comment: _commentController.text,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = 'Payment collected for ${client.fullName}.';
        _statusIsError = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.clientDetail(widget.clientId));
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

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    final clientAsync = ref.watch(
      currentGymClientDocumentProvider(widget.clientId),
    );
    final subscriptionsAsync = ref.watch(
      currentGymClientSubscriptionsProvider(widget.clientId),
    );
    final transactionsAsync = ref.watch(
      currentGymClientTransactionsProvider(widget.clientId),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => handleAppRouteBack(
            context,
            fallbackLocation: AppRoutes.clientDetail(widget.clientId),
          ),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to client profile',
        ),
        title: const Text('Collect payment'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: clientAsync.when(
                  loading: () => const _CollectPaymentLoadingCard(),
                  error: (error, stackTrace) =>
                      _CollectPaymentErrorCard(message: error.toString()),
                  data: (client) {
                    if (client == null) {
                      return const _CollectPaymentEmptyCard(
                        title: 'Client unavailable',
                        message:
                            'The current client document could not be resolved.',
                      );
                    }

                    return subscriptionsAsync.when(
                      loading: () => const _CollectPaymentLoadingCard(),
                      error: (error, stackTrace) =>
                          _CollectPaymentErrorCard(message: error.toString()),
                      data: (subscriptions) {
                        return transactionsAsync.when(
                          loading: () => const _CollectPaymentLoadingCard(),
                          error: (error, stackTrace) =>
                              _CollectPaymentErrorCard(
                                message: error.toString(),
                              ),
                          data: (transactions) {
                            final finance = resolveClientFinanceResolution(
                              subscriptions: subscriptions,
                              transactions: transactions,
                            );
                            final selectedSubscription =
                                finance.selectedSubscription;

                            if (selectedSubscription == null) {
                              return const _CollectPaymentEmptyCard(
                                title: 'No subscription found',
                                message:
                                    'Payment collection needs an audited subscription context first.',
                              );
                            }

                            if (finance.debt <= 0) {
                              return _CollectPaymentEmptyCard(
                                title: 'Nothing to collect',
                                message:
                                    'This subscription currently has no remaining debt.',
                                onBack: () => context.go(
                                  AppRoutes.clientDetail(widget.clientId),
                                ),
                              );
                            }

                            final amounts = _paymentAmounts(finance.debt);

                            return ListView(
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          client.fullName,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Collect payment using the working web contract: createTransaction(payment, category=package).',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium,
                                        ),
                                        const SizedBox(height: 16),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            _FinanceMetricChip(
                                              label: 'Package',
                                              value:
                                                  selectedSubscription
                                                      .packageName ??
                                                  'Unknown',
                                            ),
                                            _FinanceMetricChip(
                                              label: 'Paid amount',
                                              value: _formatAmount(
                                                finance.totalPaid,
                                                withUnit: true,
                                              ),
                                              tone: _CollectTone.success,
                                            ),
                                            _FinanceMetricChip(
                                              label: 'Debt',
                                              value: _formatAmount(
                                                finance.debt,
                                                withUnit: true,
                                              ),
                                              tone: _CollectTone.danger,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Payment',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                        const SizedBox(height: 12),
                                        _AmountLine(
                                          label: 'Remaining to collect',
                                          value: _formatAmount(
                                            finance.debt,
                                            withUnit: true,
                                          ),
                                          tone: _CollectTone.danger,
                                        ),
                                        const SizedBox(height: 16),
                                        ..._paymentMethods.map(
                                          (method) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: _PaymentMethodRow(
                                              method: method,
                                              activeMethod: _activeMethod,
                                              controller: _controllerFor(
                                                method.key,
                                              ),
                                              onActivate: _isSubmitting
                                                  ? null
                                                  : () => _activateMethod(
                                                      method.key,
                                                      finance.debt,
                                                    ),
                                              onChanged: _isSubmitting
                                                  ? null
                                                  : (value) => _updateAmount(
                                                      method.key,
                                                      value,
                                                      finance.debt,
                                                    ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _QuickAmountButton(
                                              label: '+50k',
                                              onPressed: _isSubmitting
                                                  ? null
                                                  : () {
                                                      final method =
                                                          _activeMethod ??
                                                          'cash';
                                                      _activateMethod(
                                                        method,
                                                        finance.debt,
                                                      );
                                                      _updateAmount(
                                                        method,
                                                        '50000',
                                                        finance.debt,
                                                      );
                                                    },
                                            ),
                                            _QuickAmountButton(
                                              label: '+100k',
                                              onPressed: _isSubmitting
                                                  ? null
                                                  : () {
                                                      final method =
                                                          _activeMethod ??
                                                          'cash';
                                                      _activateMethod(
                                                        method,
                                                        finance.debt,
                                                      );
                                                      _updateAmount(
                                                        method,
                                                        '100000',
                                                        finance.debt,
                                                      );
                                                    },
                                            ),
                                            _QuickAmountButton(
                                              label: 'Full debt',
                                              isPrimary: true,
                                              onPressed: _isSubmitting
                                                  ? null
                                                  : () {
                                                      final method =
                                                          _activeMethod ??
                                                          'cash';
                                                      _activateMethod(
                                                        method,
                                                        finance.debt,
                                                      );
                                                      _updateAmount(
                                                        method,
                                                        finance.debt.toString(),
                                                        finance.debt,
                                                      );
                                                    },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                          controller: _commentController,
                                          minLines: 2,
                                          maxLines: 4,
                                          textInputAction: TextInputAction.done,
                                          decoration: InputDecoration(
                                            labelText: 'Comment',
                                            hintText: amounts.usesDebt
                                                ? 'Explain the debt portion'
                                                : 'Optional note',
                                            errorText:
                                                amounts.usesDebt &&
                                                    _commentController.text
                                                        .trim()
                                                        .isEmpty
                                                ? 'Debt payments require a comment.'
                                                : null,
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                        const SizedBox(height: 16),
                                        _AmountLine(
                                          label: 'Paid now',
                                          value: _formatAmount(
                                            amounts.paidTotal,
                                            withUnit: true,
                                          ),
                                          tone: _CollectTone.success,
                                        ),
                                        const SizedBox(height: 10),
                                        _AmountLine(
                                          label: 'Remaining after payment',
                                          value: _formatAmount(
                                            amounts.remaining < 0
                                                ? 0
                                                : amounts.remaining,
                                            withUnit: true,
                                          ),
                                          tone: amounts.remaining.abs() < 0.01
                                              ? _CollectTone.success
                                              : _CollectTone.danger,
                                        ),
                                        if (_statusMessage != null) ...[
                                          const SizedBox(height: 16),
                                          _InlineStatus(
                                            message: _statusMessage!,
                                            isError: _statusIsError,
                                          ),
                                        ],
                                        const SizedBox(height: 18),
                                        FilledButton.icon(
                                          onPressed: _isSubmitting
                                              ? null
                                              : () => _submit(
                                                  client: client,
                                                  subscription:
                                                      selectedSubscription,
                                                  total: finance.debt,
                                                ),
                                          icon: Icon(
                                            _isSubmitting
                                                ? Icons.sync_rounded
                                                : Icons.payments_rounded,
                                          ),
                                          label: Text(
                                            _isSubmitting
                                                ? 'Collecting payment...'
                                                : 'Confirm payment',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
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

const _paymentMethods = <({String key, String label, IconData icon})>[
  (key: 'cash', label: 'Cash', icon: Icons.payments_rounded),
  (key: 'terminal', label: 'Terminal', icon: Icons.credit_card_rounded),
  (key: 'click', label: 'Click', icon: Icons.phone_android_rounded),
  (key: 'debt', label: 'Debt', icon: Icons.warning_amber_rounded),
];

class _CollectPaymentLoadingCard extends StatelessWidget {
  const _CollectPaymentLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collect payment'),
            SizedBox(height: 12),
            LinearProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading client finance context...'),
          ],
        ),
      ),
    );
  }
}

class _CollectPaymentErrorCard extends StatelessWidget {
  const _CollectPaymentErrorCard({required this.message});

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
            Text(
              'Collect payment unavailable',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _CollectPaymentEmptyCard extends StatelessWidget {
  const _CollectPaymentEmptyCard({
    required this.title,
    required this.message,
    this.onBack,
  });

  final String title;
  final String message;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
            if (onBack != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to client profile'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _CollectTone { defaultTone, success, danger }

class _FinanceMetricChip extends StatelessWidget {
  const _FinanceMetricChip({
    required this.label,
    required this.value,
    this.tone = _CollectTone.defaultTone,
  });

  final String label;
  final String value;
  final _CollectTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      _CollectTone.success => Colors.green.shade400,
      _CollectTone.danger => theme.colorScheme.error,
      _CollectTone.defaultTone => theme.colorScheme.onSurface,
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
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

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({
    required this.method,
    required this.activeMethod,
    required this.controller,
    required this.onActivate,
    required this.onChanged,
  });

  final ({String key, String label, IconData icon}) method;
  final String? activeMethod;
  final TextEditingController controller;
  final VoidCallback? onActivate;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = activeMethod == method.key;

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: FilledButton.tonalIcon(
            onPressed: onActivate,
            icon: Icon(method.icon),
            label: Text(method.label),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            enabled: isActive && onChanged != null,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Amount',
              suffixText: currentAppCurrencyCode(),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }

    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({
    required this.label,
    required this.value,
    this.tone = _CollectTone.defaultTone,
  });

  final String label;
  final String value;
  final _CollectTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      _CollectTone.success => Colors.green.shade400,
      _CollectTone.danger => theme.colorScheme.error,
      _CollectTone.defaultTone => theme.colorScheme.onSurface,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.labelLarge)),
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

class _InlineStatus extends StatelessWidget {
  const _InlineStatus({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final foreground = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyLarge?.copyWith(color: foreground),
      ),
    );
  }
}

String _formatAmount(num value, {bool withUnit = false}) {
  return formatAppMoney(value, withUnit: withUnit);
}
