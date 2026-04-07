import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/client_actions_service.dart';
import '../application/client_detail_providers.dart';
import '../application/clients_providers.dart';
import '../domain/client_detail_models.dart';
import '../domain/client_summary.dart';
import 'start_session_dialog.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchController = TextEditingController();
  bool _isMutatingSession = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startSession(GymClientSummary client) async {
    if (_isMutatingSession) {
      return;
    }

    final dialogResult = await showStartSessionDialog(
      context,
      clientName: client.fullName,
    );

    if (dialogResult == null || !mounted) {
      return;
    }

    setState(() => _isMutatingSession = true);

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${client.fullName} session started.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutatingSession = false);
      }
    }
  }

  Future<void> _endSession(GymClientSummary client, String sessionId) async {
    if (_isMutatingSession) {
      return;
    }

    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End session'),
        content: Text(
          'End the active session for ${client.fullName}? This matches the production endSession flow and will consume a visit if the client has an active subscription.',
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

    setState(() => _isMutatingSession = true);

    try {
      final result = await ref
          .read(clientActionsServiceProvider)
          .endSession(sessionId: sessionId);

      if (!mounted) {
        return;
      }

      final debtSuffix = result.barDebt != null && result.barDebt! > 0
          ? ' Bar debt: ${result.barDebt}.'
          : '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${client.fullName} session ended.$debtSuffix')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutatingSession = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(bootstrapControllerProvider);
    final session = bootstrapState.session;
    final clientsAsync = ref.watch(currentGymClientsStreamProvider);
    final subscriptions = ref
        .watch(currentGymSubscriptionsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <ClientSubscriptionSummary>[],
        );
    final clientSessions = ref
        .watch(currentGymSessionsProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const <ClientSessionSummary>[],
        );
    final theme = Theme.of(context);
    final searchQuery = _searchController.text;

    final canAccessClients = _canAccessClients(session);
    final runtimeStateByClient = _buildClientRuntimeState(
      subscriptions: subscriptions,
      sessions: clientSessions,
    );

    return AppShellBody(
      child: !canAccessClients
          ? _ClientsAccessBlocked(onBack: () => context.go(AppRoutes.app))
          : clientsAsync.when(
              loading: () => _ClientsLoadingCard(gymName: session?.gym?.name),
              error: (error, stackTrace) =>
                  _ClientsErrorCard(message: error.toString()),
              data: (clients) {
                final filteredClients = clients
                    .where((client) => client.matchesSearch(searchQuery))
                    .toList(growable: false);

                return ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session?.gym?.name ?? 'Current gym',
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Live read-only clients list from gyms/${session?.gymId}/clients with active records ordered by newest first.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search_rounded),
                                labelText: 'Search by name, phone, or email',
                                suffixIcon: searchQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _InfoChip(
                                  icon: Icons.people_alt_rounded,
                                  label: '${clients.length} clients',
                                ),
                                if (searchQuery.isNotEmpty)
                                  _InfoChip(
                                    icon: Icons.filter_alt_rounded,
                                    label: '${filteredClients.length} matching',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () =>
                                  context.go(AppRoutes.createClient),
                              icon: const Icon(Icons.person_add_alt_1_rounded),
                              label: const Text('New client'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (filteredClients.isEmpty)
                      _ClientsEmptyCard(
                        hasSearch: searchQuery.trim().isNotEmpty,
                      )
                    else
                      ...filteredClients.map(
                        (client) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ClientCard(
                            client: client,
                            runtimeState: runtimeStateByClient[client.id],
                            isActionBusy: _isMutatingSession,
                            onPrimaryAction: () {
                              final runtimeState =
                                  runtimeStateByClient[client.id];
                              final activeSession = runtimeState?.activeSession;

                              if (activeSession != null) {
                                _endSession(client, activeSession.id);
                                return;
                              }

                              if (runtimeState?.canStartSession == true) {
                                _startSession(client);
                              }
                            },
                            onTap: () =>
                                context.go(AppRoutes.clientDetail(client.id)),
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

bool _canAccessClients(ResolvedAuthSession? session) {
  if (session == null) {
    return false;
  }

  final role = session.role;
  final gymId = session.gymId;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

class _ClientsLoadingCard extends StatelessWidget {
  const _ClientsLoadingCard({this.gymName});

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
            Text(gymName ?? 'Clients', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading current gym clients...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientsErrorCard extends StatelessWidget {
  const _ClientsErrorCard({required this.message});

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
            Text('Clients unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'The clients query failed for the current gym.',
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

class _ClientsEmptyCard extends StatelessWidget {
  const _ClientsEmptyCard({required this.hasSearch});

  final bool hasSearch;

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
              hasSearch ? 'No matching clients' : 'No clients yet',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              hasSearch
                  ? 'Try a different name, phone number, or email.'
                  : 'No active client documents were returned for this gym.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientsAccessBlocked extends StatelessWidget {
  const _ClientsAccessBlocked({required this.onBack});

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
            Text('Clients unavailable', style: theme.textTheme.headlineSmall),
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

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onTap,
    required this.runtimeState,
    required this.isActionBusy,
    required this.onPrimaryAction,
  });

  final GymClientSummary client;
  final VoidCallback onTap;
  final _ClientRuntimeState? runtimeState;
  final bool isActionBusy;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryActionLabel = runtimeState?.primaryActionLabel;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: client.imageUrl != null
                    ? NetworkImage(client.imageUrl!)
                    : null,
                child: client.imageUrl == null
                    ? Text(
                        client.initials,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.fullName, style: theme.textTheme.titleMedium),
                    if (client.phone != null) ...[
                      const SizedBox(height: 6),
                      Text(client.phone!, style: theme.textTheme.bodyLarge),
                    ],
                    if (client.email != null) ...[
                      const SizedBox(height: 4),
                      Text(client.email!, style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 10),
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
                        if (runtimeState?.packageLabel != null)
                          _InfoChip(
                            icon: runtimeState!.activeSession != null
                                ? Icons.play_circle_rounded
                                : runtimeState!.hasScheduledPackage
                                ? Icons.schedule_rounded
                                : Icons.inventory_2_rounded,
                            label: runtimeState!.packageLabel!,
                          ),
                        if (runtimeState?.activeSession?.locker != null)
                          _InfoChip(
                            icon: Icons.lock_outline_rounded,
                            label:
                                'Locker ${runtimeState!.activeSession!.locker}',
                          ),
                      ],
                    ),
                    if (primaryActionLabel != null) ...[
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: isActionBusy ? null : onPrimaryAction,
                        icon: Icon(
                          runtimeState?.activeSession != null
                              ? Icons.stop_circle_rounded
                              : Icons.play_circle_fill_rounded,
                        ),
                        label: Text(primaryActionLabel),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientRuntimeState {
  const _ClientRuntimeState({
    this.activeSubscription,
    this.scheduledSubscription,
    this.activeSession,
  });

  final ClientSubscriptionSummary? activeSubscription;
  final ClientSubscriptionSummary? scheduledSubscription;
  final ClientSessionSummary? activeSession;

  bool get hasScheduledPackage => scheduledSubscription != null;

  bool get canStartSession {
    if (activeSubscription == null || activeSession != null) {
      return false;
    }

    final visitLimit = activeSubscription!.visitLimit;
    final remainingVisits = activeSubscription!.remainingVisits ?? 0;

    return visitLimit == null || remainingVisits > 0;
  }

  String? get primaryActionLabel {
    if (activeSession != null) {
      return 'End session';
    }

    if (canStartSession) {
      return 'Give key';
    }

    return null;
  }

  String? get packageLabel {
    if (activeSession != null) {
      return activeSubscription?.packageName ?? 'Active session';
    }

    if (activeSubscription != null) {
      final packageName = activeSubscription!.packageName ?? 'Active package';
      final remainingVisits = activeSubscription!.remainingVisits;
      if (remainingVisits != null && activeSubscription!.visitLimit != null) {
        return '$packageName • $remainingVisits left';
      }

      return packageName;
    }

    if (scheduledSubscription != null) {
      return '${scheduledSubscription!.packageName ?? 'Scheduled package'} • scheduled';
    }

    return null;
  }
}

Map<String, _ClientRuntimeState> _buildClientRuntimeState({
  required List<ClientSubscriptionSummary> subscriptions,
  required List<ClientSessionSummary> sessions,
}) {
  final activeSubscriptions = <String, ClientSubscriptionSummary>{};
  final scheduledSubscriptions = <String, ClientSubscriptionSummary>{};
  final activeSessions = <String, ClientSessionSummary>{};

  for (final subscription in subscriptions) {
    final clientId = subscription.clientId;
    if (clientId == null || clientId.isEmpty) {
      continue;
    }

    if (subscription.status == 'active') {
      final existing = activeSubscriptions[clientId];
      if (_isSubscriptionNewer(subscription, existing)) {
        activeSubscriptions[clientId] = subscription;
      }
      continue;
    }

    if (subscription.status == 'scheduled') {
      final existing = scheduledSubscriptions[clientId];
      if (_isSubscriptionNewer(subscription, existing)) {
        scheduledSubscriptions[clientId] = subscription;
      }
    }
  }

  for (final session in sessions) {
    final clientId = session.clientId;
    if (clientId == null || clientId.isEmpty || session.status != 'active') {
      continue;
    }

    final existing = activeSessions[clientId];
    if (_isSessionNewer(session, existing)) {
      activeSessions[clientId] = session;
    }
  }

  final allClientIds = {
    ...activeSubscriptions.keys,
    ...scheduledSubscriptions.keys,
    ...activeSessions.keys,
  };

  return {
    for (final clientId in allClientIds)
      clientId: _ClientRuntimeState(
        activeSubscription: activeSubscriptions[clientId],
        scheduledSubscription: scheduledSubscriptions[clientId],
        activeSession: activeSessions[clientId],
      ),
  };
}

bool _isSubscriptionNewer(
  ClientSubscriptionSummary candidate,
  ClientSubscriptionSummary? current,
) {
  if (current == null) {
    return true;
  }

  final candidateDate =
      candidate.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  final currentDate =
      current.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  return candidateDate.isAfter(currentDate);
}

bool _isSessionNewer(
  ClientSessionSummary candidate,
  ClientSessionSummary? current,
) {
  if (current == null) {
    return true;
  }

  final candidateDate =
      candidate.effectiveDate ?? DateTime.fromMillisecondsSinceEpoch(0);
  final currentDate =
      current.effectiveDate ?? DateTime.fromMillisecondsSinceEpoch(0);
  return candidateDate.isAfter(currentDate);
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

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
