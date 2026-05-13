import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_route_back_scope.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../sessions/application/sessions_providers.dart';
import '../../sessions/domain/gym_session_summary.dart';

class BarMenuScreen extends ConsumerWidget {
  const BarMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrapState = ref.watch(bootstrapControllerProvider);
    final session = bootstrapState.session;
    final sessionsAsync = ref.watch(currentGymSessionsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => handleAppRouteBack(
            context,
            fallbackLocation: AppRoutes.app,
          ),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to app',
        ),
        title: const Text('POS Menu'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AppShellBody(
            maxWidth: 620,
            child: !_canAccessBarMenu(session)
                ? const _BarMenuBlockedCard()
                : sessionsAsync.when(
                    loading: () =>
                        _BarMenuLoadingCard(gymName: session?.gym?.name),
                    error: (error, stackTrace) =>
                        _BarMenuErrorCard(message: error.toString()),
                    data: (sessions) {
                      final activeSessions =
                          sessions
                              .where(
                                (session) =>
                                    session.isActive &&
                                    (session.clientId?.trim().isNotEmpty ??
                                        false),
                              )
                              .toList(growable: false)
                            ..sort((left, right) {
                              final leftTime =
                                  left.startedAt ??
                                  left.createdAt ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              final rightTime =
                                  right.startedAt ??
                                  right.createdAt ??
                                  DateTime.fromMillisecondsSinceEpoch(0);
                              return rightTime.compareTo(leftTime);
                            });

                      return ListView(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          session?.gym?.name ?? 'POS Menu',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.headlineSmall,
                                        ),
                                      ),
                                      if (_canManageBar(session))
                                        FilledButton.tonalIcon(
                                          onPressed: () =>
                                              context.go(AppRoutes.barAdmin),
                                          style: FilledButton.styleFrom(
                                            minimumSize: const Size(0, 44),
                                          ),
                                          icon: const Icon(Icons.tune_rounded),
                                          label: const Text('Bar admin'),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Web source-of-truth opens POS from the global header, then serves an active client/session. Select an active session below to continue.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _InfoChip(
                                        icon: Icons.point_of_sale_rounded,
                                        label:
                                            '${activeSessions.length} active POS clients',
                                      ),
                                      const _InfoChip(
                                        icon: Icons.shopping_bag_rounded,
                                        label: 'Guest POS available',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _GuestPosCard(
                            onOpen: () => context.go(AppRoutes.barGuestPos),
                          ),
                          const SizedBox(height: 12),
                          if (activeSessions.isEmpty)
                            const _BarMenuEmptyCard()
                          else
                            ...activeSessions.map(
                              (activeSession) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ActiveSessionCard(
                                  session: activeSession,
                                  onOpen: () => context.go(
                                    AppRoutes.barPos(
                                      activeSession.clientId!,
                                      activeSession.id,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

bool _canAccessBarMenu(ResolvedAuthSession? session) {
  if (session == null) {
    return false;
  }

  final gymId = session.gymId;
  final role = session.role;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

bool _canManageBar(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null && gymId.isNotEmpty && role == AllClubsRole.owner;
}

class _BarMenuLoadingCard extends StatelessWidget {
  const _BarMenuLoadingCard({this.gymName});

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
            Text(gymName ?? 'POS Menu', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading active sessions for the POS launcher...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarMenuBlockedCard extends StatelessWidget {
  const _BarMenuBlockedCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('POS unavailable', style: theme.textTheme.headlineSmall),
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

class _BarMenuErrorCard extends StatelessWidget {
  const _BarMenuErrorCard({required this.message});

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
            Text('POS unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'The POS launcher could not load the current gym sessions.',
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

class _BarMenuEmptyCard extends StatelessWidget {
  const _BarMenuEmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No active sessions', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'POS can open for clients that currently have an active session. Guest POS remains available even when no active session exists.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({required this.session, required this.onOpen});

  final GymSessionSummary session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        session.displayClientName,
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.displayPackageName,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open POS'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (session.displayLocker != '-')
                  _InfoChip(
                    icon: Icons.lock_outline_rounded,
                    label: session.displayLocker,
                  ),
                _InfoChip(
                  icon: Icons.timer_outlined,
                  label: 'Started ${_formatTime(session.startedAt)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestPosCard extends StatelessWidget {
  const _GuestPosCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                      Text('Guest', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text(
                        'Matches the working web POS flow: createCheck with null clientId and null sessionId.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open guest POS'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.receipt_long_rounded,
                  label: 'createCheck(null, null)',
                ),
                _InfoChip(
                  icon: Icons.shopping_cart_checkout_rounded,
                  label: 'Pay / Hold / Void supported',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
          Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
        ],
      ),
    );
  }
}

String _formatTime(DateTime? value) {
  if (value == null) {
    return '-';
  }

  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
