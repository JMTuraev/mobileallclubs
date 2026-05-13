import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/developer_tools.dart';
import '../../../core/localization/app_currency.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/firebase_clients.dart';
import '../../../core/utils/phone_launcher.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/app_route_back_scope.dart';
import '../../bar/application/bar_providers.dart';
import '../../bar/domain/bar_session_check_summary.dart';
import '../../finance/application/payment_actions_service.dart';
import '../../finance/application/transaction_providers.dart';
import '../../finance/domain/client_finance_resolution.dart';
import '../../finance/domain/gym_transaction_summary.dart';
import '../../packages/application/subscription_sale_service.dart';
import '../../packages/presentation/activate_package_screen.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/client_actions_service.dart';
import '../application/client_detail_providers.dart';
import '../domain/client_detail_models.dart';
import 'client_insights_card.dart';
import 'start_session_dialog.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  const ClientDetailScreen({super.key, required this.clientId});

  final String clientId;

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  bool _isSigningOut = false;
  bool _isActionBusy = false;
  String? _actionStatusMessage;
  bool _actionStatusIsError = false;
  bool _isCardEditorVisible = false;
  final TextEditingController _cardIdController = TextEditingController();

  @override
  void dispose() {
    _cardIdController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() => _isSigningOut = true);

    try {
      await ref.read(firebaseAuthProvider).signOut();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-out failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<void> _startSession(GymClientDetail client) async {
    if (_isActionBusy) {
      return;
    }

    final dialogResult = await showStartSessionDialog(
      context,
      clientName: client.fullName,
    );

    if (dialogResult == null || !mounted) {
      return;
    }

    setState(() => _isActionBusy = true);

    try {
      await ref
          .read(clientActionsServiceProvider)
          .startSession(
            clientId: client.id,
            lockerNumber: dialogResult.lockerNumber,
          );

      if (!mounted) {
        return;
      }

      context.go(AppRoutes.clientsWithHighlight(client.id));
      return;
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = error.toString().replaceFirst('Exception: ', '');
        _actionStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _callClientPhone(String? phone) async {
    try {
      final result = await confirmAndLaunchPhoneDialer(context, phone);
      if (!mounted || result == PhoneLaunchResult.launched) {
        return;
      }

      if (result == PhoneLaunchResult.unavailable ||
          result == PhoneLaunchResult.invalid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This device cannot start a phone call.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone call could not be started.')),
      );
    }
  }

  Future<void> _endSession({
    required String sessionId,
    required String clientName,
  }) async {
    if (_isActionBusy) {
      return;
    }

    setState(() => _isActionBusy = true);

    try {
      final checks = await ref.read(barSessionChecksProvider(sessionId).future);
      final blockedMessage = buildSessionEndBlockedMessage(clientName, checks);
      if (!mounted) {
        return;
      }
      if (blockedMessage.trim().isNotEmpty) {
        setState(() {
          _actionStatusMessage = blockedMessage;
          _actionStatusIsError = true;
        });
        return;
      }

      final shouldEnd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End session'),
          content: Text(
            'End the active session for $clientName? This follows the production endSession callable and may consume one remaining visit.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('End session'),
            ),
          ],
        ),
      );

      if (shouldEnd != true || !mounted) {
        return;
      }

      final result = await ref
          .read(clientActionsServiceProvider)
          .endSession(sessionId: sessionId);

      if (!mounted) {
        return;
      }

      final debtSuffix = result.barDebt != null && result.barDebt! > 0
          ? ' Bar debt: ${result.barDebt}.'
          : '';

      setState(() {
        _actionStatusMessage = '$clientName session ended.$debtSuffix';
        _actionStatusIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = error.toString().replaceFirst('Exception: ', '');
        _actionStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  void _toggleCardEditor(GymClientDetail client) {
    setState(() {
      _isCardEditorVisible = !_isCardEditorVisible;
      if (_isCardEditorVisible) {
        _cardIdController.clear();
      }
    });
  }

  Future<void> _bindCard({
    required GymClientDetail client,
    required String gymId,
  }) async {
    if (_isActionBusy) {
      return;
    }

    final cardValue = _cardIdController.text.trim();
    if (cardValue.isEmpty) {
      setState(() {
        _actionStatusMessage = _friendlyCardError('INVALID_CARD');
        _actionStatusIsError = true;
        _isCardEditorVisible = true;
      });
      return;
    }

    setState(() => _isActionBusy = true);

    try {
      await ref
          .read(clientActionsServiceProvider)
          .bindClientCard(gymId: gymId, clientId: client.id, cardId: cardValue);

      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage =
            'Card $cardValue is now linked to ${client.fullName}.';
        _actionStatusIsError = false;
        _isCardEditorVisible = false;
        _cardIdController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = _friendlyCardError(
          error.toString().replaceFirst('Exception: ', ''),
        );
        _actionStatusIsError = true;
        _isCardEditorVisible = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _removeCard({
    required GymClientDetail client,
    required String gymId,
  }) async {
    final existingCardId = client.cardId?.trim();
    if (_isActionBusy || existingCardId == null || existingCardId.isEmpty) {
      return;
    }

    setState(() => _isActionBusy = true);

    try {
      await ref
          .read(clientActionsServiceProvider)
          .removeClientCard(
            gymId: gymId,
            clientId: client.id,
            cardId: existingCardId,
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = 'Card removed from ${client.fullName}.';
        _actionStatusIsError = false;
        _isCardEditorVisible = false;
        _cardIdController.clear();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = _friendlyCardError(
          error.toString().replaceFirst('Exception: ', ''),
        );
        _actionStatusIsError = true;
        _isCardEditorVisible = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _archiveClient(GymClientDetail client) async {
    if (_isActionBusy) {
      return;
    }

    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive client'),
        content: Text(
          'Archive ${client.fullName}? This follows the production archiveClient callable and removes the client from active lists without changing the database structure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive client'),
          ),
        ],
      ),
    );

    if (shouldArchive != true || !mounted) {
      return;
    }

    setState(() => _isActionBusy = true);

    try {
      await ref
          .read(clientActionsServiceProvider)
          .archiveClient(clientId: client.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage =
            '${client.fullName} archived. Returning to clients...';
        _actionStatusIsError = false;
      });

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        context.go(AppRoutes.clients);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = error.toString().replaceFirst('Exception: ', '');
        _actionStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _reversePayment(GymTransactionSummary payment) async {
    if (_isActionBusy) {
      return;
    }

    final shouldReverse = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete payment'),
        content: Text(
          'Create a reversing transaction for payment ${payment.id}? This follows the working web delete-payment flow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete payment'),
          ),
        ],
      ),
    );

    if (shouldReverse != true || !mounted) {
      return;
    }

    setState(() => _isActionBusy = true);

    try {
      await ref
          .read(paymentActionsServiceProvider)
          .reversePayment(clientId: widget.clientId, payment: payment);

      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = 'Payment reversed.';
        _actionStatusIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = error.toString().replaceFirst('Exception: ', '');
        _actionStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _restorePayment(GymTransactionSummary payment) async {
    if (_isActionBusy) {
      return;
    }

    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore payment'),
        content: Text(
          'Restore payment ${payment.id} by creating a compensating payment transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restore payment'),
          ),
        ],
      ),
    );

    if (shouldRestore != true || !mounted) {
      return;
    }

    setState(() => _isActionBusy = true);

    try {
      await ref
          .read(paymentActionsServiceProvider)
          .restorePayment(clientId: widget.clientId, payment: payment);

      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = 'Payment restored.';
        _actionStatusIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = error.toString().replaceFirst('Exception: ', '');
        _actionStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _editSubscriptionStartDate(
    ClientSubscriptionSummary subscription,
  ) async {
    if (_isActionBusy) {
      return;
    }

    final initialDate = DateUtils.dateOnly(
      subscription.startDate ?? DateTime.now(),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null || !mounted) {
      return;
    }

    final normalizedDate = DateUtils.dateOnly(picked);
    setState(() => _isActionBusy = true);

    try {
      await ref
          .read(subscriptionSaleServiceProvider)
          .updateSubscriptionStartDate(
            subscriptionId: subscription.id,
            newStartDate: _formatDateRequest(normalizedDate),
          );

      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = 'Subscription start date updated.';
        _actionStatusIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = error.toString().replaceFirst('Exception: ', '');
        _actionStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _updateSubscriptionStatus({
    required String title,
    required String message,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    if (_isActionBusy) {
      return;
    }

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !mounted) {
      return;
    }

    setState(() => _isActionBusy = true);

    try {
      await action();

      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = successMessage;
        _actionStatusIsError = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _actionStatusMessage = error.toString().replaceFirst('Exception: ', '');
        _actionStatusIsError = true;
      });
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  Future<void> _activateSubscription(ClientSubscriptionSummary subscription) {
    return _updateSubscriptionStatus(
      title: 'Activate subscription',
      message:
          'Activate ${subscription.packageName ?? 'this subscription'} using the exact updateSubscription callable?',
      action: () => ref
          .read(subscriptionSaleServiceProvider)
          .activateSubscription(subscriptionId: subscription.id),
      successMessage: 'Subscription activated.',
    );
  }

  Future<void> _deactivateSubscription(ClientSubscriptionSummary subscription) {
    return _updateSubscriptionStatus(
      title: 'Deactivate subscription',
      message:
          'Deactivate ${subscription.packageName ?? 'this subscription'} using the exact updateSubscription callable?',
      action: () => ref
          .read(subscriptionSaleServiceProvider)
          .deactivateSubscription(subscriptionId: subscription.id),
      successMessage: 'Subscription deactivated.',
    );
  }

  Future<void> _cancelSubscription(ClientSubscriptionSummary subscription) {
    return _updateSubscriptionStatus(
      title: 'Cancel subscription',
      message:
          'Mark ${subscription.packageName ?? 'this subscription'} as cancelled using the exact updateSubscription callable?',
      action: () => ref
          .read(subscriptionSaleServiceProvider)
          .cancelSubscription(subscriptionId: subscription.id),
      successMessage: 'Subscription cancelled.',
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    final bootstrapState = ref.watch(bootstrapControllerProvider);
    final session = bootstrapState.session;
    final canAccessClient = _canAccessClient(session, widget.clientId);
    final clientAsync = ref.watch(
      currentGymClientDocumentProvider(widget.clientId),
    );
    final subscriptionsAsync = ref.watch(
      currentGymClientSubscriptionsProvider(widget.clientId),
    );
    final sessionsAsync = ref.watch(
      currentGymClientSessionsProvider(widget.clientId),
    );
    final transactionsAsync = ref.watch(
      currentGymClientTransactionsProvider(widget.clientId),
    );
    final activeSubscription = subscriptionsAsync.maybeWhen(
      data: (subscriptions) => _firstActiveSubscription(subscriptions),
      orElse: () => null,
    );
    final activeSession = sessionsAsync.maybeWhen(
      data: (sessions) => _firstActiveSession(sessions),
      orElse: () => null,
    );
    final canStartSession =
        activeSubscription != null &&
        activeSession == null &&
        (activeSubscription.visitLimit == null ||
            (activeSubscription.remainingVisits ?? 0) > 0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              handleAppRouteBack(context, fallbackLocation: AppRoutes.clients),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to clients',
        ),
        title: const Text('Client profile'),
        actions: [
          IconButton(
            onPressed: _isSigningOut ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: !canAccessClient
                    ? const _ClientDetailBlockedCard()
                    : clientAsync.when(
                        loading: () => const _ClientDetailLoadingCard(),
                        error: (error, stackTrace) => _ClientDetailErrorCard(
                          title: 'Client profile unavailable',
                          message: error.toString(),
                        ),
                        data: (client) {
                          if (client == null) {
                            return const _ClientDetailMissingCard();
                          }

                          return ListView(
                            children: [
                              _ClientHeroCard(
                                client: client,
                                gymName: session?.gym?.name,
                                onPhoneTap: client.phone == null
                                    ? null
                                    : () => _callClientPhone(client.phone),
                              ),
                              const SizedBox(height: 12),
                              _ClientActionCard(
                                activeSubscription: activeSubscription,
                                activeSession: activeSession,
                                currentCardId: client.cardId,
                                cardIdController: _cardIdController,
                                isBusy: _isActionBusy,
                                isCardEditorVisible: _isCardEditorVisible,
                                statusMessage: _actionStatusMessage,
                                statusIsError: _actionStatusIsError,
                                onActivatePackage: () {
                                  if (activeSubscription != null) {
                                    context.push(
                                      AppRoutes.packageSubscriptionAction,
                                      extra: ActivatePackageRouteArgs(
                                        clientId: widget.clientId,
                                        clientName: client.fullName,
                                        clientPhone: client.phone,
                                        editSubscription: activeSubscription,
                                        popOnSuccess: true,
                                      ),
                                    );
                                    return;
                                  }

                                  context.go(
                                    AppRoutes.activatePackage(widget.clientId),
                                  );
                                },
                                onToggleCardEditor: session?.gymId == null
                                    ? null
                                    : () => _toggleCardEditor(client),
                                onSaveCard: session?.gymId == null
                                    ? null
                                    : () => _bindCard(
                                        client: client,
                                        gymId: session!.gymId!,
                                      ),
                                onRemoveCard: session?.gymId == null
                                    ? null
                                    : () => _removeCard(
                                        client: client,
                                        gymId: session!.gymId!,
                                      ),
                                onStartSession: canStartSession
                                    ? () => _startSession(client)
                                    : null,
                                onEndSession: activeSession == null
                                    ? null
                                    : () => _endSession(
                                        sessionId: activeSession.id,
                                        clientName: client.fullName,
                                      ),
                                onOpenBar: activeSession == null
                                    ? null
                                    : () => context.go(
                                        AppRoutes.barPos(
                                          widget.clientId,
                                          activeSession.id,
                                        ),
                                      ),
                                onArchiveClient:
                                    session?.role == AllClubsRole.owner
                                    ? () => _archiveClient(client)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _ClientPersonalInfoCard(
                                client: client,
                                onPhoneTap: client.phone == null
                                    ? null
                                    : () => _callClientPhone(client.phone),
                              ),
                              const SizedBox(height: 12),
                              ClientInsightsCard(clientId: widget.clientId),
                              const SizedBox(height: 12),
                              _ClientSubscriptionsCard(
                                subscriptionsAsync: subscriptionsAsync,
                                isBusy: _isActionBusy,
                                statusMessage: _actionStatusMessage,
                                statusIsError: _actionStatusIsError,
                                onEditStartDate:
                                    session?.role == AllClubsRole.owner
                                    ? _editSubscriptionStartDate
                                    : null,
                                onActivate: session?.role == AllClubsRole.owner
                                    ? _activateSubscription
                                    : null,
                                onDeactivate:
                                    session?.role == AllClubsRole.owner
                                    ? _deactivateSubscription
                                    : null,
                                onCancel: session?.role == AllClubsRole.owner
                                    ? _cancelSubscription
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              _ClientFinanceCard(
                                subscriptionsAsync: subscriptionsAsync,
                                transactionsAsync: transactionsAsync,
                                isBusy: _isActionBusy,
                                statusMessage: _actionStatusMessage,
                                statusIsError: _actionStatusIsError,
                                onCollectPayment: () => context.go(
                                  AppRoutes.collectPayment(widget.clientId),
                                ),
                                onReversePayment: _reversePayment,
                                onRestorePayment: _restorePayment,
                              ),
                              const SizedBox(height: 12),
                              _ClientSessionsCard(sessionsAsync: sessionsAsync),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => context.go(
                                  AppRoutes.sessionsForClient(widget.clientId),
                                ),
                                icon: const Icon(Icons.event_note_rounded),
                                label: const Text('Open client sessions'),
                              ),
                              if (showDeveloperDiagnosticsShortcut) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      openDeveloperDiagnostics(context),
                                  icon: const Icon(
                                    Icons.developer_mode_rounded,
                                  ),
                                  label: const Text(
                                    'Open Developer Firebase Diagnostics',
                                  ),
                                ),
                              ],
                            ],
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

bool _canAccessClient(ResolvedAuthSession? session, String clientId) {
  if (session == null) {
    return false;
  }

  final gymId = session.gymId;
  final role = session.role;

  return clientId.trim().isNotEmpty &&
      gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

class _ClientHeroCard extends StatelessWidget {
  const _ClientHeroCard({required this.client, this.gymName, this.onPhoneTap});

  final GymClientDetail client;
  final String? gymName;
  final VoidCallback? onPhoneTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final hasImage =
                    client.imageUrl != null &&
                    client.imageUrl!.trim().isNotEmpty;
                return CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: hasImage
                      ? NetworkImage(client.imageUrl!.trim())
                      : null,
                  child: !hasImage
                      ? Text(
                          client.initials,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.fullName, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  if (gymName != null && gymName!.trim().isNotEmpty)
                    Text(gymName!, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.badge_outlined,
                        label: 'ID ${client.id}',
                      ),
                      if (client.cardId != null)
                        _InfoChip(
                          icon: Icons.credit_card_rounded,
                          label: 'Card ${client.cardId}',
                        ),
                      if (client.phone != null)
                        _InfoChip(
                          icon: Icons.phone_outlined,
                          label: client.phone!,
                          onTap: onPhoneTap,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientPersonalInfoCard extends StatelessWidget {
  const _ClientPersonalInfoCard({required this.client, this.onPhoneTap});

  final GymClientDetail client;
  final VoidCallback? onPhoneTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profile', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _DetailRow(label: 'Full name', value: client.fullName),
            _DetailRow(
              label: 'Phone',
              value: client.phone ?? 'Unavailable',
              detail: client.phone == null ? null : 'Tap the number to call.',
              onTap: onPhoneTap,
            ),
            _DetailRow(label: 'Email', value: client.email ?? 'Unavailable'),
            _DetailRow(label: 'Card ID', value: client.cardId ?? 'Unavailable'),
            _DetailRow(label: 'Gender', value: client.gender ?? 'Unavailable'),
            _DetailRow(
              label: 'Age',
              value: client.age != null ? '${client.age}' : 'Unavailable',
            ),
            _DetailRow(
              label: 'Client type',
              value: client.type ?? 'Unavailable',
            ),
            _DetailRow(
              label: 'Lifetime spent',
              value: _formatMoney(client.lifetimeSpent),
            ),
            _DetailRow(
              label: 'Created',
              value: _formatDateTime(client.createdAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientActionCard extends StatelessWidget {
  const _ClientActionCard({
    required this.activeSubscription,
    required this.activeSession,
    required this.currentCardId,
    required this.cardIdController,
    required this.isBusy,
    required this.isCardEditorVisible,
    required this.statusMessage,
    required this.statusIsError,
    required this.onActivatePackage,
    required this.onToggleCardEditor,
    required this.onSaveCard,
    required this.onRemoveCard,
    required this.onStartSession,
    required this.onEndSession,
    required this.onOpenBar,
    required this.onArchiveClient,
  });

  final ClientSubscriptionSummary? activeSubscription;
  final ClientSessionSummary? activeSession;
  final String? currentCardId;
  final TextEditingController cardIdController;
  final bool isBusy;
  final bool isCardEditorVisible;
  final String? statusMessage;
  final bool statusIsError;
  final VoidCallback? onActivatePackage;
  final VoidCallback? onToggleCardEditor;
  final VoidCallback? onSaveCard;
  final VoidCallback? onRemoveCard;
  final VoidCallback? onStartSession;
  final VoidCallback? onEndSession;
  final VoidCallback? onOpenBar;
  final VoidCallback? onArchiveClient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessionStateLabel = activeSession != null
        ? 'Active session in progress'
        : activeSubscription != null
        ? 'Ready for check-in'
        : 'No active package';
    final packageLabel =
        activeSubscription?.packageName ?? 'No active subscription found';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client actions', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            _DetailRow(label: 'Package state', value: packageLabel),
            _DetailRow(label: 'Session state', value: sessionStateLabel),
            if (activeSession?.locker != null)
              _DetailRow(
                label: 'Current locker',
                value: activeSession!.locker!,
              ),
            if (statusMessage != null) ...[
              Text(
                statusMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: statusIsError
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (currentCardId != null && currentCardId!.trim().isNotEmpty) ...[
              _DetailRow(label: 'Current card', value: currentCardId!),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isCardEditorVisible
                  ? Container(
                      key: const ValueKey('card-editor-open'),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentCardId == null ||
                                    currentCardId!.trim().isEmpty
                                ? 'Bind card'
                                : 'Manage card',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            autofocus: true,
                            controller: cardIdController,
                            enabled: !isBusy,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => onSaveCard?.call(),
                            decoration: InputDecoration(
                              labelText: 'Card ID',
                              hintText:
                                  currentCardId == null ||
                                      currentCardId!.trim().isEmpty
                                  ? 'Enter card code'
                                  : 'Enter new card code',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              FilledButton(
                                onPressed: isBusy ? null : onSaveCard,
                                child: Text(isBusy ? 'Saving...' : 'Save card'),
                              ),
                              if (currentCardId != null &&
                                  currentCardId!.trim().isNotEmpty)
                                FilledButton.tonal(
                                  onPressed: isBusy ? null : onRemoveCard,
                                  child: const Text('Remove card'),
                                ),
                              TextButton(
                                onPressed: isBusy ? null : onToggleCardEditor,
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('card-editor-closed')),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : onActivatePackage,
                  icon: const Icon(Icons.auto_awesome_mosaic_rounded),
                  label: Text(
                    activeSubscription == null
                        ? 'Activate package'
                        : 'Replace package',
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : onToggleCardEditor,
                  icon: const Icon(Icons.credit_card_rounded),
                  label: const Text('Bind card'),
                ),
                FilledButton.icon(
                  onPressed: isBusy ? null : onStartSession,
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  label: const Text('Give key'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : onOpenBar,
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: const Text('Open bar POS'),
                ),
                FilledButton.tonalIcon(
                  onPressed: isBusy ? null : onEndSession,
                  icon: const Icon(Icons.stop_circle_rounded),
                  label: const Text('End session'),
                ),
                if (onArchiveClient != null)
                  FilledButton.tonalIcon(
                    onPressed: isBusy ? null : onArchiveClient,
                    icon: const Icon(Icons.archive_outlined),
                    label: const Text('Archive client'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientSubscriptionsCard extends StatelessWidget {
  const _ClientSubscriptionsCard({
    required this.subscriptionsAsync,
    required this.isBusy,
    required this.statusMessage,
    required this.statusIsError,
    this.onEditStartDate,
    this.onActivate,
    this.onDeactivate,
    this.onCancel,
  });

  final AsyncValue<List<ClientSubscriptionSummary>> subscriptionsAsync;
  final bool isBusy;
  final String? statusMessage;
  final bool statusIsError;
  final ValueChanged<ClientSubscriptionSummary>? onEditStartDate;
  final ValueChanged<ClientSubscriptionSummary>? onActivate;
  final ValueChanged<ClientSubscriptionSummary>? onDeactivate;
  final ValueChanged<ClientSubscriptionSummary>? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return subscriptionsAsync.when(
      loading: () => const _SectionLoadingCard(
        title: 'Subscription summary',
        message: 'Loading subscriptions from gyms/{gymId}/subscriptions...',
      ),
      error: (error, stackTrace) => _ClientDetailErrorCard(
        title: 'Subscription summary unavailable',
        message: error.toString(),
      ),
      data: (subscriptions) {
        final orderedSubscriptions = _orderedSubscriptions(subscriptions);

        if (orderedSubscriptions.isEmpty) {
          return const _SectionEmptyCard(
            title: 'Subscription summary',
            message: 'No subscription documents were returned for this client.',
          );
        }

        final current = orderedSubscriptions.first;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Subscription summary', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                if (orderedSubscriptions.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Showing the most relevant record from ${orderedSubscriptions.length} matching subscriptions.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                _DetailRow(
                  label: 'Current status',
                  value: current.status ?? 'Unavailable',
                ),
                _DetailRow(
                  label: 'Package',
                  value: current.packageName ?? 'Unavailable',
                ),
                _DetailRow(
                  label: 'Plan price',
                  value: _formatMoney(current.packagePrice),
                ),
                _DetailRow(
                  label: 'Plan duration',
                  value: current.packageDurationDays != null
                      ? '${current.packageDurationDays} days'
                      : 'Unavailable',
                ),
                _DetailRow(label: 'Visits', value: _formatVisits(current)),
                _DetailRow(
                  label: 'Start date',
                  value: _formatDateTime(current.startDate),
                ),
                _DetailRow(
                  label: 'End date',
                  value: _formatDateTime(current.endDate),
                ),
                if (statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    statusMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: statusIsError
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
                if (onEditStartDate != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: isBusy
                          ? null
                          : () => onEditStartDate!(current),
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: Text(isBusy ? 'Saving...' : 'Edit start date'),
                    ),
                  ),
                ],
                if (onActivate != null ||
                    onDeactivate != null ||
                    onCancel != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (onActivate != null &&
                          current.status != 'active' &&
                          current.status != 'cancelled')
                        FilledButton.tonalIcon(
                          onPressed: isBusy ? null : () => onActivate!(current),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: Text(isBusy ? 'Saving...' : 'Activate'),
                        ),
                      if (onDeactivate != null && current.status == 'active')
                        FilledButton.tonalIcon(
                          onPressed: isBusy
                              ? null
                              : () => onDeactivate!(current),
                          icon: const Icon(Icons.pause_circle_outline_rounded),
                          label: Text(isBusy ? 'Saving...' : 'Deactivate'),
                        ),
                      if (onCancel != null && current.status != 'cancelled')
                        FilledButton.tonalIcon(
                          onPressed: isBusy ? null : () => onCancel!(current),
                          icon: const Icon(Icons.cancel_outlined),
                          label: Text(
                            isBusy ? 'Saving...' : 'Cancel subscription',
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClientFinanceCard extends StatelessWidget {
  const _ClientFinanceCard({
    required this.subscriptionsAsync,
    required this.transactionsAsync,
    required this.isBusy,
    required this.statusMessage,
    required this.statusIsError,
    required this.onCollectPayment,
    required this.onReversePayment,
    required this.onRestorePayment,
  });

  final AsyncValue<List<ClientSubscriptionSummary>> subscriptionsAsync;
  final AsyncValue<List<GymTransactionSummary>> transactionsAsync;
  final bool isBusy;
  final String? statusMessage;
  final bool statusIsError;
  final VoidCallback onCollectPayment;
  final ValueChanged<GymTransactionSummary> onReversePayment;
  final ValueChanged<GymTransactionSummary> onRestorePayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return subscriptionsAsync.when(
      loading: () => const _SectionLoadingCard(
        title: 'Finance summary',
        message: 'Loading subscriptions for finance summary...',
      ),
      error: (error, stackTrace) => _ClientDetailErrorCard(
        title: 'Finance summary unavailable',
        message: error.toString(),
      ),
      data: (subscriptions) {
        final orderedSubscriptions = orderClientSubscriptions(subscriptions);
        if (orderedSubscriptions.isEmpty) {
          return const _SectionEmptyCard(
            title: 'Finance summary',
            message:
                'No subscription context is available for finance summary.',
          );
        }

        return transactionsAsync.when(
          loading: () => const _SectionLoadingCard(
            title: 'Finance summary',
            message:
                'Loading transactions from gyms/{gymId}/transactions and gyms/{gymId}/financeTransactions...',
          ),
          error: (error, stackTrace) => _ClientDetailErrorCard(
            title: 'Finance summary unavailable',
            message: error.toString(),
          ),
          data: (transactions) {
            final finance = resolveClientFinanceResolution(
              subscriptions: subscriptions,
              transactions: transactions,
            );

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Finance summary', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: finance.canCollectPayment
                            ? onCollectPayment
                            : null,
                        icon: const Icon(Icons.payments_rounded),
                        label: const Text('Collect payment'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current finance snapshot for the selected subscription from the audited production contract.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _MetricChip(
                          label: 'Package price',
                          value: _formatMoney(finance.totalOwed),
                        ),
                        _MetricChip(
                          label: 'Paid amount',
                          value: _formatMoney(finance.totalPaid),
                          tone: _MetricTone.success,
                        ),
                        _MetricChip(
                          label: 'Debt',
                          value: _formatMoney(finance.debt),
                          tone: finance.debt > 0
                              ? _MetricTone.danger
                              : _MetricTone.success,
                        ),
                        _MetricChip(
                          label: 'Overpayment',
                          value: _formatMoney(finance.overpayment),
                          tone: finance.overpayment > 0
                              ? _MetricTone.success
                              : _MetricTone.defaultTone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      label: 'Remaining',
                      value: _formatMoney(finance.debt > 0 ? finance.debt : 0),
                    ),
                    _DetailRow(
                      label: 'Linked payments',
                      value: '${finance.selectedPayments.length}',
                    ),
                    if (statusMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        statusMessage!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: statusIsError
                              ? theme.colorScheme.error
                              : theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('Payments list', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    if (finance.selectedPayments.isEmpty)
                      Text(
                        'No payments linked to this subscription.',
                        style: theme.textTheme.bodyLarge,
                      )
                    else
                      ...finance.selectedPayments.map(
                        (payment) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _PaymentRow(
                            payment: payment,
                            isBusy: isBusy,
                            onAction: switch (payment.type) {
                              'payment' => () => onReversePayment(payment),
                              'payment_reverse' => () => onRestorePayment(
                                payment,
                              ),
                              _ => null,
                            },
                            actionLabel: switch (payment.type) {
                              'payment' => 'Delete',
                              'payment_reverse' => 'Restore',
                              _ => null,
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ClientSessionsCard extends StatelessWidget {
  const _ClientSessionsCard({required this.sessionsAsync});

  final AsyncValue<List<ClientSessionSummary>> sessionsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return sessionsAsync.when(
      loading: () => const _SectionLoadingCard(
        title: 'Session summary',
        message: 'Loading sessions from gyms/{gymId}/sessions...',
      ),
      error: (error, stackTrace) => _ClientDetailErrorCard(
        title: 'Session summary unavailable',
        message: error.toString(),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const _SectionEmptyCard(
            title: 'Session summary',
            message: 'No session documents were returned for this client.',
          );
        }

        final orderedSessions = [...sessions]
          ..sort((left, right) {
            final leftDate =
                left.effectiveDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            final rightDate =
                right.effectiveDate ?? DateTime.fromMillisecondsSinceEpoch(0);
            return rightDate.compareTo(leftDate);
          });

        ClientSessionSummary? activeSession;
        for (final session in orderedSessions) {
          if (session.status == 'active') {
            activeSession = session;
            break;
          }
        }

        final lastVisit = orderedSessions.first.effectiveDate;
        final completedCount = sessions
            .where((session) => session.status == 'completed')
            .length;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Session summary', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _DetailRow(
                  label: 'Live status',
                  value: activeSession != null ? 'Active now' : 'Inactive',
                  detail: activeSession?.locker != null
                      ? 'Locker ${activeSession!.locker}'
                      : null,
                ),
                _DetailRow(
                  label: 'Started',
                  value: _formatDateTime(activeSession?.startedAt),
                  detail: activeSession?.startedAt != null
                      ? 'Duration ${_formatDurationSince(activeSession!.startedAt!)}'
                      : null,
                ),
                _DetailRow(
                  label: 'Last visit',
                  value: _formatDateTime(lastVisit),
                ),
                _DetailRow(
                  label: 'Completed sessions',
                  value: '$completedCount',
                ),
                _DetailRow(
                  label: 'Loaded session records',
                  value: '${orderedSessions.length}',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ClientDetailLoadingCard extends StatelessWidget {
  const _ClientDetailLoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client profile', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading the current client document...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientDetailMissingCard extends StatelessWidget {
  const _ClientDetailMissingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client not found', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'The client document is not available in the current gym context.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientDetailBlockedCard extends StatelessWidget {
  const _ClientDetailBlockedCard();

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
              'Client profile unavailable',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              'This route requires an owner or staff account with a resolved gym context.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientDetailErrorCard extends StatelessWidget {
  const _ClientDetailErrorCard({required this.title, required this.message});

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

class _SectionLoadingCard extends StatelessWidget {
  const _SectionLoadingCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionEmptyCard extends StatelessWidget {
  const _SectionEmptyCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(message, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.detail,
    this.onTap,
  });

  final String label;
  final String value;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          if (onTap == null)
            Text(value, style: theme.textTheme.bodyLarge)
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(
                        Icons.call_outlined,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Container(
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
          Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.call_outlined,
              size: 14,
              color: theme.colorScheme.primary,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: content,
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.payment,
    this.isBusy = false,
    this.onAction,
    this.actionLabel,
  });

  final GymTransactionSummary payment;
  final bool isBusy;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.paymentMethod ?? payment.type ?? 'Payment',
                  style: theme.textTheme.labelLarge,
                ),
              ),
              Text(
                _formatMoney(payment.amount),
                style: theme.textTheme.labelLarge,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            payment.category ?? 'package',
            style: theme.textTheme.bodyMedium,
          ),
          if (payment.comment != null && payment.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(payment.comment!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 4),
          Text(
            _formatDateTime(payment.createdAt),
            style: theme.textTheme.bodyMedium,
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: isBusy ? null : onAction,
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _MetricTone { defaultTone, success, danger }

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    this.tone = _MetricTone.defaultTone,
  });

  final String label;
  final String value;
  final _MetricTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (tone) {
      _MetricTone.success => Colors.green.shade700,
      _MetricTone.danger => theme.colorScheme.error,
      _MetricTone.defaultTone => theme.colorScheme.onSurface,
    };

    return Container(
      constraints: const BoxConstraints(minWidth: 180),
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

List<ClientSubscriptionSummary> _orderedSubscriptions(
  List<ClientSubscriptionSummary> subscriptions,
) {
  return orderClientSubscriptions(subscriptions);
}

String _formatMoney(num? value) {
  if (value == null) {
    return 'Unavailable';
  }

  return formatAppMoney(value);
}

String _formatVisits(ClientSubscriptionSummary subscription) {
  if (subscription.isUnlimited == true) {
    return 'Unlimited';
  }

  if (subscription.visitLimit == null) {
    return 'Unavailable';
  }

  final used = subscription.visitsUsed;
  final remaining = subscription.remainingVisits;

  if (used == null || remaining == null) {
    return '${subscription.visitLimit} total';
  }

  return '$remaining remaining of ${subscription.visitLimit} ($used used)';
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return 'Unavailable';
  }

  final local = value.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String _formatDateRequest(DateTime value) {
  final normalized = DateUtils.dateOnly(value);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

String _formatDurationSince(DateTime startedAt) {
  final difference = DateTime.now().difference(startedAt.toLocal());

  if (difference.inMinutes < 1) {
    return 'under 1 minute';
  }

  if (difference.inHours < 1) {
    return '${difference.inMinutes} min';
  }

  if (difference.inDays < 1) {
    final hours = difference.inHours;
    final minutes = difference.inMinutes.remainder(60);
    if (minutes == 0) {
      return '$hours h';
    }

    return '$hours h $minutes min';
  }

  final days = difference.inDays;
  final hours = difference.inHours.remainder(24);
  if (hours == 0) {
    return '$days d';
  }

  return '$days d $hours h';
}

ClientSubscriptionSummary? _firstActiveSubscription(
  List<ClientSubscriptionSummary> subscriptions,
) {
  final ordered = _orderedSubscriptions(subscriptions);
  for (final subscription in ordered) {
    if (subscription.status == 'active') {
      return subscription;
    }
  }

  return null;
}

ClientSessionSummary? _firstActiveSession(List<ClientSessionSummary> sessions) {
  final ordered = [...sessions]
    ..sort((left, right) {
      final leftDate =
          left.effectiveDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          right.effectiveDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });

  for (final session in ordered) {
    if (session.status == 'active') {
      return session;
    }
  }

  return null;
}

String? _friendlyCardError(String? code) {
  return switch (code) {
    null => null,
    'INVALID_CARD' => 'Card ID is required.',
    'CARD_ALREADY_LINKED' => 'This card is already linked to another client.',
    'CLIENT_ALREADY_HAS_CARD' =>
      'Remove the current card before binding a new one.',
    'CARD_LINKED_TO_ANOTHER_CLIENT' =>
      'This card is linked to another client and cannot be removed here.',
    'CLIENT_NOT_FOUND' => 'The selected client document does not exist.',
    _ => code,
  };
}
