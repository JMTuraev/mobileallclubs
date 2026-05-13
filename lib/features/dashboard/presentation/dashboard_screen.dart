import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_route_back_scope.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/dashboard_providers.dart';
import '../domain/owner_analytics_models.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final analyticsAsync = ref.watch(ownerAnalytics30DayProvider);
    final dailyStatsAsync = ref.watch(currentGymDailyStatsProvider);

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
        title: const Text('Stats'),
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AppShellBody(
            maxWidth: 560,
            child: !_canAccessDashboard(session)
                ? const _DashboardBlockedCard()
                : dailyStatsAsync.when(
                    loading: () => const _DashboardLoadingCard(),
                    error: (error, stackTrace) =>
                        _DashboardErrorCard(message: error.toString()),
                    data: (dailyStats) {
                      if (session?.role == AllClubsRole.staff) {
                        return _StaffDailyStatsView(
                          session: session,
                          dailyStats: dailyStats,
                        );
                      }

                      return analyticsAsync.when(
                        loading: () => _OwnerDashboardLoadingView(
                          session: session,
                          dailyStats: dailyStats,
                        ),
                        error: (error, stackTrace) => _OwnerDashboardErrorView(
                          session: session,
                          dailyStats: dailyStats,
                          message: error.toString(),
                        ),
                        data: (series) => _OwnerDashboardView(
                          session: session,
                          dailyStats: dailyStats,
                          series: series,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

bool _canAccessDashboard(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

class _DashboardBlockedCard extends StatelessWidget {
  const _DashboardBlockedCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stats unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'This route requires a resolved gym user session.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoadingCard extends StatelessWidget {
  const _DashboardLoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stats', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading today through getGymDailyStats...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardErrorCard extends StatelessWidget {
  const _DashboardErrorCard({required this.message});

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
            Text('Stats unavailable', style: theme.textTheme.headlineSmall),
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

class _StaffDailyStatsView extends StatelessWidget {
  const _StaffDailyStatsView({
    required this.session,
    required this.dailyStats,
  });

  final ResolvedAuthSession? session;
  final GymDailyStatsSnapshot? dailyStats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _CurrentGymDailyStatsCard(session: session, dailyStats: dailyStats),
        const SizedBox(height: 12),
        const _OwnerAnalyticsBlockedCard(),
      ],
    );
  }
}

class _OwnerDashboardLoadingView extends StatelessWidget {
  const _OwnerDashboardLoadingView({
    required this.session,
    required this.dailyStats,
  });

  final ResolvedAuthSession? session;
  final GymDailyStatsSnapshot? dailyStats;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _CurrentGymDailyStatsCard(session: session, dailyStats: dailyStats),
        const SizedBox(height: 12),
        const _OwnerAnalyticsLoadingCard(),
      ],
    );
  }
}

class _OwnerDashboardErrorView extends StatelessWidget {
  const _OwnerDashboardErrorView({
    required this.session,
    required this.dailyStats,
    required this.message,
  });

  final ResolvedAuthSession? session;
  final GymDailyStatsSnapshot? dailyStats;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _CurrentGymDailyStatsCard(session: session, dailyStats: dailyStats),
        const SizedBox(height: 12),
        _DashboardErrorCard(message: message),
      ],
    );
  }
}

class _OwnerDashboardView extends StatelessWidget {
  const _OwnerDashboardView({
    required this.session,
    required this.dailyStats,
    required this.series,
  });

  final ResolvedAuthSession? session;
  final GymDailyStatsSnapshot? dailyStats;
  final OwnerAnalyticsSeries? series;

  @override
  Widget build(BuildContext context) {
    final latest = series?.latest;
    final recentDays = series == null
        ? const <OwnerAnalyticsDay>[]
        : [...series!.days.reversed.take(7)];

    return ListView(
      children: [
        _CurrentGymDailyStatsCard(session: session, dailyStats: dailyStats),
        const SizedBox(height: 12),
        if (series == null || latest == null)
          const _DashboardEmptyCard()
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owner analytics',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Exact getOwnerAnalytics callable data for the last 30 days.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricChip(label: 'Date', value: latest.date),
                      _MetricChip(
                        label: 'Revenue',
                        value: _formatMoney(latest.revenue),
                      ),
                      _MetricChip(
                        label: 'Sessions',
                        value: '${latest.totalSessions}',
                      ),
                      _MetricChip(
                        label: 'Active clients',
                        value: '${latest.activeClients}',
                      ),
                      _MetricChip(
                        label: 'New clients',
                        value: '${latest.newClients}',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Owned gyms on ${latest.date}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (latest.gyms.isEmpty)
                    Text(
                      'No owned gym rows were returned for this date.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    )
                  else
                    ...latest.gyms.map(
                      (gym) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GymAnalyticsCard(gym: gym),
                      ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent 7 days',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  ...recentDays.map(
                    (day) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RecentDayRow(day: day),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CurrentGymDailyStatsCard extends StatelessWidget {
  const _CurrentGymDailyStatsCard({
    required this.session,
    required this.dailyStats,
  });

  final ResolvedAuthSession? session;
  final GymDailyStatsSnapshot? dailyStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today gym stats', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'Exact getGymDailyStats callable data for ${session?.gym?.name ?? session?.gymId ?? 'the current gym'}.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            if (dailyStats == null)
              Text(
                'No daily stats row was returned.',
                style: theme.textTheme.bodyLarge,
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricChip(label: 'Date', value: dailyStats!.date),
                  _MetricChip(
                    label: 'Revenue',
                    value: _formatMoney(dailyStats!.revenue),
                  ),
                  _MetricChip(
                    label: 'Sessions',
                    value: '${dailyStats!.totalSessions}',
                  ),
                  _MetricChip(
                    label: 'Active clients',
                    value: '${dailyStats!.activeClients}',
                  ),
                  _MetricChip(
                    label: 'New clients',
                    value: '${dailyStats!.newClients}',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _OwnerAnalyticsBlockedCard extends StatelessWidget {
  const _OwnerAnalyticsBlockedCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner analytics unavailable', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Text(
              'The current working web contract exposes getOwnerAnalytics for owner sessions only.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerAnalyticsLoadingCard extends StatelessWidget {
  const _OwnerAnalyticsLoadingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner analytics', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading the last 30 days through getOwnerAnalytics...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardEmptyCard extends StatelessWidget {
  const _DashboardEmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner analytics', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'No owner analytics rows were returned.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _GymAnalyticsCard extends StatelessWidget {
  const _GymAnalyticsCard({required this.gym});

  final OwnedGymDailySummary gym;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = gym.peakHours.isEmpty ? null : gym.peakHours.first;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(gym.gymName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricChip(label: 'Revenue', value: _formatMoney(gym.revenue)),
              _MetricChip(label: 'Sessions', value: '${gym.totalSessions}'),
              _MetricChip(
                label: 'Active clients',
                value: '${gym.activeClients}',
              ),
              _MetricChip(label: 'New clients', value: '${gym.newClients}'),
            ],
          ),
          if (peak != null) ...[
            const SizedBox(height: 12),
            Text(
              'Peak hour: ${peak.hour} (${peak.sessionsCount} sessions)',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentDayRow extends StatelessWidget {
  const _RecentDayRow({required this.day});

  final OwnerAnalyticsDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(child: Text(day.date, style: theme.textTheme.labelLarge)),
          Text('${day.totalSessions} sessions', style: theme.textTheme.bodyMedium),
          const SizedBox(width: 12),
          Text(_formatMoney(day.revenue), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 130),
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
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

String _formatMoney(num value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
}
