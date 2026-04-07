import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../clients/application/client_detail_providers.dart';
import '../../clients/application/clients_providers.dart';
import '../../clients/domain/client_detail_models.dart';
import '../../clients/domain/client_summary.dart';
import '../application/package_actions_service.dart';
import '../application/package_providers.dart';
import '../domain/gym_package_summary.dart';
import 'activate_package_screen.dart';

class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key});

  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

enum _PackagesTab { templates, sold }

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  _PackagesTab _selectedTab = _PackagesTab.templates;
  bool _isDeleting = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _deletePackage(GymPackageSummary package) async {
    if (_isDeleting) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete package'),
        content: Text(
          'Archive ${package.name ?? package.id}? Active clients will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _statusMessage = null;
      _statusIsError = false;
    });

    try {
      await ref
          .read(packageActionsServiceProvider)
          .deletePackage(packageId: package.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage = '${package.name ?? package.id} archived.';
        _statusIsError = false;
      });
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
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _openEditSheet(GymPackageSummary package) async {
    context.go(AppRoutes.editPackage, extra: package);
  }

  Future<void> _openSubscriptionAction({
    required ClientSubscriptionSummary subscription,
    required String clientName,
    required String? clientPhone,
    required bool editStartOnly,
  }) async {
    final clientId = subscription.clientId?.trim();
    if (clientId == null || clientId.isEmpty) {
      setState(() {
        _statusMessage = 'Missing subscription clientId.';
        _statusIsError = true;
      });
      return;
    }

    await context.push(
      AppRoutes.packageSubscriptionAction,
      extra: ActivatePackageRouteArgs(
        clientId: clientId,
        clientName: clientName,
        clientPhone: clientPhone,
        editSubscription: subscription,
        editStartOnly: editStartOnly,
        popOnSuccess: true,
      ),
    );
  }

  List<Widget> _buildTemplateContent({
    required AsyncValue<List<GymPackageSummary>> packagesAsync,
    required bool isOwner,
    required String? gymName,
  }) {
    return packagesAsync.when(
      loading: () => [
        _PackagesLoadingCard(
          gymName: gymName,
          message: 'Loading current gym package templates...',
        ),
      ],
      error: (error, stackTrace) => [
        _PackagesErrorCard(
          title: 'Packages unavailable',
          description:
              'The package template stream failed for the current gym.',
          message: error.toString(),
        ),
      ],
      data: (packages) {
        if (packages.isEmpty) {
          return const [_PackagesEmptyCard()];
        }

        return packages
            .map(
              (package) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PackageCard(
                  package: package,
                  isOwner: isOwner,
                  isBusy: _isDeleting,
                  onEdit: isOwner ? () => _openEditSheet(package) : null,
                  onDelete: isOwner ? () => _deletePackage(package) : null,
                ),
              ),
            )
            .toList(growable: false);
      },
    );
  }

  List<Widget> _buildSoldContent({
    required AsyncValue<List<ClientSubscriptionSummary>> subscriptionsAsync,
    required AsyncValue<List<GymClientSummary>> clientsAsync,
    required bool isOwner,
    required String? gymName,
  }) {
    return subscriptionsAsync.when(
      loading: () => [
        _PackagesLoadingCard(
          gymName: gymName,
          message: 'Loading sold packages from the current gym...',
        ),
      ],
      error: (error, stackTrace) => [
        _PackagesErrorCard(
          title: 'Sold packages unavailable',
          description:
              'The sold subscription stream failed for the current gym.',
          message: error.toString(),
        ),
      ],
      data: (subscriptions) {
        if (subscriptions.isEmpty) {
          return const [
            _PackagesEmptyCard(
              title: 'No sold packages yet',
              message: 'The current gym has no sold subscriptions yet.',
            ),
          ];
        }

        final clients =
            clientsAsync.asData?.value ?? const <GymClientSummary>[];
        final activeCount = subscriptions
            .where((subscription) => subscription.normalizedStatus == 'active')
            .length;
        final scheduledCount = subscriptions
            .where(
              (subscription) => subscription.normalizedStatus == 'scheduled',
            )
            .length;
        final expiredCount = subscriptions
            .where((subscription) => subscription.normalizedStatus == 'expired')
            .length;
        final replacedCount = subscriptions
            .where(
              (subscription) => subscription.normalizedStatus == 'replaced',
            )
            .length;

        return [
          _SoldPackageSummaryCard(
            totalCount: subscriptions.length,
            activeCount: activeCount,
            scheduledCount: scheduledCount,
            expiredCount: expiredCount,
            replacedCount: replacedCount,
          ),
          const SizedBox(height: 12),
          ...subscriptions.map((subscription) {
            final client = _resolveClient(subscription, clients);
            final clientName = _resolveClientName(subscription, client);
            final clientPhone = _resolveClientPhone(subscription, client);
            final canEdit =
                isOwner &&
                subscription.normalizedStatus != 'replaced' &&
                (subscription.sessionsCount ?? 0) <= 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SoldSubscriptionCard(
                subscription: subscription,
                clientName: clientName,
                clientPhone: clientPhone,
                canEdit: canEdit,
                canReplace: canEdit,
                onEdit: canEdit
                    ? () => _openSubscriptionAction(
                        subscription: subscription,
                        clientName: clientName,
                        clientPhone: clientPhone,
                        editStartOnly: true,
                      )
                    : null,
                onReplace: canEdit
                    ? () => _openSubscriptionAction(
                        subscription: subscription,
                        clientName: clientName,
                        clientPhone: clientPhone,
                        editStartOnly: false,
                      )
                    : null,
              ),
            );
          }),
        ];
      },
    );
  }

  GymClientSummary? _resolveClient(
    ClientSubscriptionSummary subscription,
    List<GymClientSummary> clients,
  ) {
    final clientId = subscription.clientId;
    if (clientId == null || clientId.isEmpty) {
      return null;
    }

    for (final client in clients) {
      if (client.id == clientId) {
        return client;
      }
    }

    return null;
  }

  String _resolveClientName(
    ClientSubscriptionSummary subscription,
    GymClientSummary? client,
  ) {
    final subscriptionName = subscription.clientName?.trim();
    if (subscriptionName != null && subscriptionName.isNotEmpty) {
      return subscriptionName;
    }

    if (client != null) {
      return client.fullName;
    }

    return 'Unknown client';
  }

  String? _resolveClientPhone(
    ClientSubscriptionSummary subscription,
    GymClientSummary? client,
  ) {
    final subscriptionPhone = subscription.clientPhone?.trim();
    if (subscriptionPhone != null && subscriptionPhone.isNotEmpty) {
      return subscriptionPhone;
    }

    return client?.phone;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final packagesAsync = ref.watch(currentGymPackagesProvider);
    final subscriptionsAsync = ref.watch(currentGymSubscriptionsProvider);
    final clientsAsync = ref.watch(currentGymClientsStreamProvider);
    final theme = Theme.of(context);
    final isOwner = session?.role == AllClubsRole.owner;
    final packages = packagesAsync.asData?.value ?? const <GymPackageSummary>[];
    final subscriptions =
        subscriptionsAsync.asData?.value ?? const <ClientSubscriptionSummary>[];
    final freezeEnabledCount = packages
        .where((package) => package.freezeEnabled == true)
        .length;
    final restrictedCount = packages
        .where(
          (package) =>
              (package.startTime != null && package.startTime!.isNotEmpty) ||
              (package.endTime != null && package.endTime!.isNotEmpty),
        )
        .length;
    final sectionChildren = _selectedTab == _PackagesTab.templates
        ? _buildTemplateContent(
            packagesAsync: packagesAsync,
            isOwner: isOwner,
            gymName: session?.gym?.name,
          )
        : _buildSoldContent(
            subscriptionsAsync: subscriptionsAsync,
            clientsAsync: clientsAsync,
            isOwner: isOwner,
            gymName: session?.gym?.name,
          );

    return AppShellBody(
      child: !_canAccessPackages(session)
          ? _PackagesAccessBlocked(onBack: () => context.go(AppRoutes.app))
          : ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session?.gym?.name ?? 'Packages',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Live package templates from gyms/${session?.gymId}/packages and sold subscriptions from gyms/${session?.gymId}/subscriptions.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _PackageChip(
                              icon: Icons.auto_awesome_mosaic_rounded,
                              label: '${packages.length} templates',
                            ),
                            _PackageChip(
                              icon: Icons.sell_rounded,
                              label: '${subscriptions.length} sold',
                            ),
                            _PackageChip(
                              icon: Icons.ac_unit_rounded,
                              label: '$freezeEnabledCount freeze-enabled',
                            ),
                            _PackageChip(
                              icon: Icons.schedule_rounded,
                              label: '$restrictedCount time-restricted',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Templates'),
                              selected: _selectedTab == _PackagesTab.templates,
                              onSelected: (_) => setState(
                                () => _selectedTab = _PackagesTab.templates,
                              ),
                            ),
                            ChoiceChip(
                              label: const Text('Sold packages'),
                              selected: _selectedTab == _PackagesTab.sold,
                              onSelected: (_) => setState(
                                () => _selectedTab = _PackagesTab.sold,
                              ),
                            ),
                          ],
                        ),
                        if (isOwner &&
                            _selectedTab == _PackagesTab.templates) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () =>
                                context.go(AppRoutes.createPackage),
                            icon: const Icon(Icons.add_box_rounded),
                            label: const Text('New package'),
                          ),
                        ],
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _statusMessage!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _statusIsError
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...sectionChildren,
                if (kDebugMode) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.firebaseDiagnostics),
                    icon: const Icon(Icons.developer_mode_rounded),
                    label: const Text('Open Developer Firebase Diagnostics'),
                  ),
                ],
              ],
            ),
    );
  }
}

bool _canAccessPackages(ResolvedAuthSession? session) {
  final gymId = session?.gymId;
  final role = session?.role ?? AllClubsRole.unknown;

  return gymId != null &&
      gymId.isNotEmpty &&
      (role == AllClubsRole.owner || role == AllClubsRole.staff);
}

class _PackagesLoadingCard extends StatelessWidget {
  const _PackagesLoadingCard({
    this.gymName,
    this.message = 'Loading current gym package templates...',
  });

  final String? gymName;
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
            Text(gymName ?? 'Packages', style: theme.textTheme.headlineSmall),
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

class _PackagesErrorCard extends StatelessWidget {
  const _PackagesErrorCard({
    required this.message,
    this.title = 'Packages unavailable',
    this.description =
        'The package template stream failed for the current gym.',
  });

  final String message;
  final String title;
  final String description;

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
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(description, style: theme.textTheme.bodyLarge),
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

class _PackagesAccessBlocked extends StatelessWidget {
  const _PackagesAccessBlocked({required this.onBack});

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
            Text('Packages unavailable', style: theme.textTheme.headlineSmall),
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

class _PackagesEmptyCard extends StatelessWidget {
  const _PackagesEmptyCard({
    this.title = 'No packages found',
    this.message = 'The current gym has no active package templates yet.',
  });

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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(message, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _SoldPackageSummaryCard extends StatelessWidget {
  const _SoldPackageSummaryCard({
    required this.totalCount,
    required this.activeCount,
    required this.scheduledCount,
    required this.expiredCount,
    required this.replacedCount,
  });

  final int totalCount;
  final int activeCount;
  final int scheduledCount;
  final int expiredCount;
  final int replacedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sold packages', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PackageChip(
                  icon: Icons.receipt_long_rounded,
                  label: '$totalCount subscriptions',
                ),
                _PackageChip(
                  icon: Icons.check_circle_rounded,
                  label: '$activeCount active',
                ),
                _PackageChip(
                  icon: Icons.schedule_rounded,
                  label: '$scheduledCount scheduled',
                ),
                _PackageChip(
                  icon: Icons.history_toggle_off_rounded,
                  label: '$expiredCount expired',
                ),
                _PackageChip(
                  icon: Icons.swap_horiz_rounded,
                  label: '$replacedCount replaced',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoldSubscriptionCard extends StatelessWidget {
  const _SoldSubscriptionCard({
    required this.subscription,
    required this.clientName,
    required this.clientPhone,
    required this.canEdit,
    required this.canReplace,
    this.onEdit,
    this.onReplace,
  });

  final ClientSubscriptionSummary subscription;
  final String clientName;
  final String? clientPhone;
  final bool canEdit;
  final bool canReplace;
  final VoidCallback? onEdit;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = subscription.normalizedStatus;
    final visitsText = subscription.visitLimit == null
        ? 'Unlimited'
        : '${subscription.visitsUsed ?? 0} / ${subscription.visitLimit}';

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
                      Text(clientName, style: theme.textTheme.titleMedium),
                      if (clientPhone != null && clientPhone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(clientPhone!, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        subscription.packageName ?? 'Unknown package',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                _StatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PackageChip(icon: Icons.repeat_rounded, label: visitsText),
                _PackageChip(
                  icon: Icons.calendar_today_rounded,
                  label: _formatDate(subscription.startDate),
                ),
                _PackageChip(
                  icon: Icons.event_busy_rounded,
                  label: _formatDate(subscription.endDate),
                ),
                if ((subscription.sessionsCount ?? 0) > 0)
                  _PackageChip(
                    icon: Icons.fitness_center_rounded,
                    label: '${subscription.sessionsCount} sessions',
                  ),
              ],
            ),
            if (subscription.replaceComment != null &&
                subscription.replaceComment!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                subscription.replaceComment!,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (canEdit || canReplace) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canEdit)
                    OutlinedButton(
                      onPressed: onEdit,
                      child: const Text('Edit'),
                    ),
                  if (canReplace)
                    FilledButton.tonal(
                      onPressed: onReplace,
                      child: const Text('Replace'),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (background, foreground, label) = switch (status) {
      'active' => (Colors.green.shade700, Colors.white, 'Active'),
      'scheduled' => (Colors.blue.shade700, Colors.white, 'Scheduled'),
      'expired' => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        'Expired',
      ),
      'cancelled' => (Colors.grey.shade700, Colors.white, 'Cancelled'),
      'replaced' => (theme.colorScheme.error, Colors.white, 'Replaced'),
      _ => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        status,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(color: foreground),
      ),
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.package,
    required this.isOwner,
    required this.isBusy,
    this.onEdit,
    this.onDelete,
  });

  final GymPackageSummary package;
  final bool isOwner;
  final bool isBusy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visitLimit = package.effectiveVisitLimit;

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
                        package.name ?? 'Unnamed package',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Gradient ${package.gradient ?? 'from-indigo-500 to-indigo-700'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        onPressed: isBusy ? null : onEdit,
                        icon: const Icon(Icons.edit_rounded),
                        tooltip: 'Edit package',
                      ),
                      IconButton(
                        onPressed: isBusy ? null : onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: 'Delete package',
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (package.price != null)
                  _PackageChip(
                    icon: Icons.payments_rounded,
                    label: _formatAmount(package.price!),
                  ),
                if (package.duration != null)
                  _PackageChip(
                    icon: Icons.date_range_rounded,
                    label: '${package.duration} days',
                  ),
                if (package.bonusDays != null && package.bonusDays! > 0)
                  _PackageChip(
                    icon: Icons.add_circle_outline_rounded,
                    label: '+${package.bonusDays} bonus',
                  ),
                if (visitLimit != null)
                  _PackageChip(
                    icon: Icons.repeat_rounded,
                    label: '$visitLimit visits',
                  ),
                _PackageChip(
                  icon: Icons.wc_rounded,
                  label: package.gender ?? 'all',
                ),
                if (package.freezeEnabled == true)
                  _PackageChip(
                    icon: Icons.ac_unit_rounded,
                    label: 'Freeze ${package.maxFreezeDays ?? 0}',
                  ),
              ],
            ),
            if ((package.startTime != null && package.startTime!.isNotEmpty) ||
                (package.endTime != null && package.endTime!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              Text(
                '${package.startTime ?? '--:--'} -> ${package.endTime ?? '--:--'}',
                style: theme.textTheme.bodyLarge,
              ),
            ],
            if (package.description != null &&
                package.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(package.description!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _PackageChip extends StatelessWidget {
  const _PackageChip({required this.icon, required this.label});

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

String _formatAmount(num value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toStringAsFixed(2);
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return '-';
  }

  final normalized = value.toLocal();
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}
