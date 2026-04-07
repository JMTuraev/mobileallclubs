import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/client_insights_providers.dart';
import '../domain/client_insights_summary.dart';

class ClientInsightsCard extends ConsumerWidget {
  const ClientInsightsCard({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(clientInsightsProvider(clientId));
    final theme = Theme.of(context);

    return insightsAsync.when(
      loading: () => const _StateCard(
        title: 'Client insights',
        message: 'Loading getClientInsights...',
        loading: true,
      ),
      error: (error, stackTrace) => _StateCard(
        title: 'Client insights unavailable',
        message: error.toString(),
        color: theme.colorScheme.error,
      ),
      data: (insights) {
        if (insights == null) {
          return const _StateCard(
            title: 'Client insights',
            message: 'This client is outside the current resolved gym context.',
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Client insights', style: theme.textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(
                  'Exact getClientInsights callable data from gyms/{gymId}/clientInsights/{clientId}.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricChip(
                      label: 'Last 30 visits',
                      value: '${insights.last30Visits}',
                    ),
                    _MetricChip(
                      label: 'Previous 30',
                      value: '${insights.previous30Visits}',
                    ),
                    _MetricChip(
                      label: 'Trend',
                      value:
                          '${insights.attendanceDirection} (${_signed(insights.attendanceDelta)})',
                    ),
                    _MetricChip(
                      label: 'Visits / week',
                      value: _formatNumber(insights.visitsPerWeek),
                    ),
                    _MetricChip(
                      label: 'Inactive days',
                      value: insights.inactiveDays?.toString() ?? 'unknown',
                    ),
                    _MetricChip(label: 'Churn risk', value: insights.churnRisk),
                    _MetricChip(
                      label: 'Lifetime value',
                      value: _formatNumber(insights.lifetimeValue),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailRow(
                  label: 'Last visit',
                  value: _formatDateTime(insights.lastVisitAt),
                ),
                const SizedBox(height: 8),
                Text('Smart alerts', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                if (insights.alerts.isEmpty)
                  Text(
                    'No backend smart alerts were returned.',
                    style: theme.textTheme.bodyLarge,
                  )
                else
                  ...insights.alerts.map(
                    (alert) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _AlertRow(alert: alert),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.title,
    required this.message,
    this.loading = false,
    this.color,
  });

  final String title;
  final String message;
  final bool loading;
  final Color? color;

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
            if (loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(color: color),
            ),
          ],
        ),
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
      constraints: const BoxConstraints(minWidth: 160),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.alert});

  final ClientInsightAlert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (alert.severity) {
      'high' => theme.colorScheme.error,
      'medium' => Colors.orange.shade400,
      _ => theme.colorScheme.primary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(alert.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(alert.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            '${alert.type} • ${alert.severity}',
            style: theme.textTheme.labelMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

String _signed(int value) {
  if (value > 0) {
    return '+$value';
  }

  return '$value';
}

String _formatNumber(num value) {
  if (value % 1 == 0) {
    return value.toStringAsFixed(0);
  }

  return value.toStringAsFixed(2);
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
