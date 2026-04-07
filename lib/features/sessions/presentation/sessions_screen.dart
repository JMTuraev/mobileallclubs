import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../clients/application/client_detail_providers.dart';
import '../../clients/domain/client_detail_models.dart';
import '../application/sessions_providers.dart';
import '../domain/gym_session_summary.dart';

class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key, this.clientId});

  final String? clientId;

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapState = ref.watch(bootstrapControllerProvider);
    final session = bootstrapState.session;
    final filteredSessionsAsync = ref.watch(
      filteredGymSessionsProvider(widget.clientId),
    );
    final filteredClientAsync = widget.clientId == null
        ? const AsyncValue<GymClientDetail?>.data(null)
        : ref.watch(currentGymClientDocumentProvider(widget.clientId!));
    final isNestedClientFlow = widget.clientId?.trim().isNotEmpty == true;
    return AppShellBody(
      child: !_canAccessSessions(session)
          ? _SessionsAccessBlocked(
              onBack: () => context.go(
                isNestedClientFlow
                    ? AppRoutes.clientDetail(widget.clientId!)
                    : AppRoutes.app,
              ),
            )
          : ListView(
              children: [
                if (isNestedClientFlow) ...[
                  _NestedClientSessionsBanner(
                    onBack: () =>
                        context.go(AppRoutes.clientDetail(widget.clientId!)),
                  ),
                  const SizedBox(height: 12),
                  _FilteredClientCard(
                    clientAsync: filteredClientAsync,
                    clientId: widget.clientId!,
                  ),
                  const SizedBox(height: 12),
                ],
                ...filteredSessionsAsync.when(
                  loading: () => [
                    _SessionsLoadingCard(gymName: session?.gym?.name),
                  ],
                  error: (error, stackTrace) => [
                    _SessionsErrorCard(message: error.toString()),
                  ],
                  data: (sessions) {
                    final activeCount = sessions
                        .where((session) => session.isActive)
                        .length;
                    final closedCount = sessions
                        .where((session) => session.isClosed)
                        .length;

                    return [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session?.gym?.name ?? 'Sessions',
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Live read-only sessions stream from gyms/${session?.gymId}/sessions ordered by newest first with a 500-session cap.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _InfoChip(
                                    icon: Icons.event_note_rounded,
                                    label: '${sessions.length} sessions',
                                  ),
                                  _InfoChip(
                                    icon: Icons.play_circle_rounded,
                                    label: '$activeCount active',
                                  ),
                                  _InfoChip(
                                    icon: Icons.check_circle_outline_rounded,
                                    label: '$closedCount closed',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (sessions.isEmpty)
                        const _SessionsEmptyCard()
                      else
                        ...sessions.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SessionCard(session: session),
                          ),
                        ),
                    ];
                  },
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.firebaseDiagnostics),
                    icon: const Icon(Icons.developer_mode_rounded),
                    label: const Text(
                      'Open Developer Firebase Diagnostics',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _NestedClientSessionsBanner extends StatelessWidget {
  const _NestedClientSessionsBanner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client sessions', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Filtered sessions stay inside the shared mobile shell so the fixed header and bottom dock do not jump between pages.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to client'),
            ),
          ],
        ),
      ),
    );
  }
}

bool _canAccessSessions(ResolvedAuthSession? session) {
  if (session == null) {
    return false;
  }

  final gymId = session.gymId;
  final role = session.role;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

class _FilteredClientCard extends StatelessWidget {
  const _FilteredClientCard({
    required this.clientAsync,
    required this.clientId,
  });

  final AsyncValue<GymClientDetail?> clientAsync;
  final String clientId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: clientAsync.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client filter', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ),
          error: (error, stackTrace) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client filter', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(
                'Showing sessions for clientId $clientId',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
          data: (client) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Client filter', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(
                'Showing sessions filtered by clientId, matching the working web sessions page.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              _InfoChip(
                icon: Icons.person_outline_rounded,
                label: client?.fullName ?? clientId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionsLoadingCard extends StatelessWidget {
  const _SessionsLoadingCard({this.gymName});

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
            Text(gymName ?? 'Sessions', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading current gym sessions...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsErrorCard extends StatelessWidget {
  const _SessionsErrorCard({required this.message});

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
            Text('Sessions unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'The sessions stream failed for the current gym.',
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

class _SessionsEmptyCard extends StatelessWidget {
  const _SessionsEmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No sessions found', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'The working web contract returned no session documents for the current filter.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionsAccessBlocked extends StatelessWidget {
  const _SessionsAccessBlocked({required this.onBack});

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
            Text('Sessions unavailable', style: theme.textTheme.headlineSmall),
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

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final GymSessionSummary session;

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
                        session.displayClientName,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        session.displayPackageName,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                _StatusPill(isOnline: session.isOnline),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.badge_outlined,
                  label: 'ID ${session.id}',
                ),
                _InfoChip(
                  icon: Icons.lock_outline_rounded,
                  label: 'Locker ${session.displayLocker}',
                ),
                _InfoChip(
                  icon: Icons.person_pin_circle_outlined,
                  label: session.displayStaffName,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(
              label: 'Check-in',
              value: _formatTime(session.startedAt),
            ),
            _DetailRow(label: 'Check-out', value: _formatTime(session.endedAt)),
            _DetailRow(
              label: 'Duration',
              value: _formatDuration(session.startedAt, session.endedAt),
            ),
            _DetailRow(
              label: 'Status field',
              value: session.status ?? 'Unavailable',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isOnline
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(
          color: isOnline
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: theme.textTheme.bodyLarge)),
        ],
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

String _formatDuration(DateTime? start, DateTime? end) {
  if (start == null) {
    return '-';
  }

  final endTime = end?.toLocal() ?? DateTime.now();
  final startTime = start.toLocal();
  final difference = endTime.difference(startTime);
  final hours = difference.inHours;
  final minutes = difference.inMinutes.remainder(60);

  return '${hours}h ${minutes}m';
}
