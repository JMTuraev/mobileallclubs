import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/developer_tools.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_control_widgets.dart';
import '../../../core/widgets/app_date_range_filter_sheet.dart';
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

enum _SoldSubscriptionTab { total, active, replaced, expired }

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  _PackagesTab _selectedTab = _PackagesTab.templates;
  AppDateRangeFilter _selectedDateFilter = AppDateRangeFilter.allTime();
  _SoldSubscriptionTab _selectedSoldTab = _SoldSubscriptionTab.total;
  bool _isDeleting = false;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _pickDateFilter() async {
    final picked = await showAppDateRangeFilterSheet(
      context: context,
      title: 'Packages range',
      selectedFilter: _selectedDateFilter,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDateFilter = picked;
    });
  }

  void _selectTab(_PackagesTab tab) {
    if (_selectedTab == tab) {
      return;
    }

    setState(() {
      _selectedTab = tab;
    });
  }

  void _selectSoldTab(_SoldSubscriptionTab tab) {
    if (_selectedSoldTab == tab) {
      return;
    }

    setState(() {
      _selectedSoldTab = tab;
    });
  }

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

        final rangedSubscriptions = _filterSubscriptionsByDate(subscriptions);
        final visibleSubscriptions = _filterSubscriptionsByStatus(
          rangedSubscriptions,
        );

        if (visibleSubscriptions.isEmpty) {
          return const [
            _PackagesEmptyCard(
              title: 'No subscriptions found',
              message: 'Nothing matched the selected filters.',
            ),
          ];
        }

        final clients =
            clientsAsync.asData?.value ?? const <GymClientSummary>[];
        return visibleSubscriptions
            .map((subscription) {
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
            })
            .toList(growable: false);
      },
    );
  }

  List<ClientSubscriptionSummary> _filterSubscriptionsByDate(
    List<ClientSubscriptionSummary> subscriptions,
  ) {
    return subscriptions
        .where((subscription) {
          final targetDate =
              subscription.startDate ??
              subscription.createdAt ??
              subscription.endDate;

          if (targetDate == null) {
            return _selectedDateFilter.preset ==
                AppDateRangeFilterPreset.allTime;
          }

          return appDateRangeIncludesDate(_selectedDateFilter, targetDate);
        })
        .toList(growable: false);
  }

  List<ClientSubscriptionSummary> _filterSubscriptionsByStatus(
    List<ClientSubscriptionSummary> subscriptions,
  ) {
    return subscriptions
        .where((subscription) {
          return switch (_selectedSoldTab) {
            _SoldSubscriptionTab.total => true,
            _SoldSubscriptionTab.active =>
              subscription.normalizedStatus == 'active',
            _SoldSubscriptionTab.replaced =>
              subscription.normalizedStatus == 'replaced',
            _SoldSubscriptionTab.expired =>
              subscription.normalizedStatus == 'expired',
          };
        })
        .toList(growable: false);
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
    final isOwner = session?.role == AllClubsRole.owner;
    final packages = packagesAsync.asData?.value ?? const <GymPackageSummary>[];
    final subscriptions =
        subscriptionsAsync.asData?.value ?? const <ClientSubscriptionSummary>[];
    final rangedSubscriptions = _filterSubscriptionsByDate(subscriptions);
    final soldCounts = _SoldSubscriptionCounts.from(rangedSubscriptions);
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
    final headerExtent = _selectedTab == _PackagesTab.sold ? 154.0 : 46.0;
    final bodyChildren = <Widget>[
      if (_statusMessage != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _PackagesStatusBanner(
            message: _statusMessage!,
            isError: _statusIsError,
          ),
        ),
      if (isOwner && _selectedTab == _PackagesTab.templates)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go(AppRoutes.createPackage),
              icon: const Icon(Icons.add_box_rounded),
              label: const Text('Create package'),
            ),
          ),
        ),
      ...sectionChildren,
      if (showDeveloperDiagnosticsShortcut) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => openDeveloperDiagnostics(context),
          icon: const Icon(Icons.developer_mode_rounded),
          label: const Text('Open Developer Firebase Diagnostics'),
        ),
      ],
    ];

    return AppShellBody(
      expandHeight: true,
      padding: appControlsPagePadding,
      child: !_canAccessPackages(session)
          ? _PackagesAccessBlocked(onBack: () => context.go(AppRoutes.app))
          : CustomScrollView(
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: AppControlsSliverHeaderDelegate(
                    extent: headerExtent,
                    child: _PackagesControlsHeader(
                      selectedTab: _selectedTab,
                      templateCount: packages.length,
                      subscriptionCount: subscriptions.length,
                      soldCounts: soldCounts,
                      selectedDateFilter: _selectedDateFilter,
                      selectedSoldTab: _selectedSoldTab,
                      onPickDate: _pickDateFilter,
                      onSelectTab: _selectTab,
                      onSelectSoldTab: _selectSoldTab,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(bodyChildren),
                  ),
                ),
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

class _PackagesControlsHeader extends StatelessWidget {
  const _PackagesControlsHeader({
    required this.selectedTab,
    required this.templateCount,
    required this.subscriptionCount,
    required this.soldCounts,
    required this.selectedDateFilter,
    required this.selectedSoldTab,
    required this.onPickDate,
    required this.onSelectTab,
    required this.onSelectSoldTab,
  });

  final _PackagesTab selectedTab;
  final int templateCount;
  final int subscriptionCount;
  final _SoldSubscriptionCounts soldCounts;
  final AppDateRangeFilter selectedDateFilter;
  final _SoldSubscriptionTab selectedSoldTab;
  final VoidCallback onPickDate;
  final ValueChanged<_PackagesTab> onSelectTab;
  final ValueChanged<_SoldSubscriptionTab> onSelectSoldTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 42,
          child: Row(
            children: [
              Expanded(
                child: AppControlTogglePill(
                  label: 'Templates',
                  icon: Icons.widgets_rounded,
                  count: templateCount,
                  selected: selectedTab == _PackagesTab.templates,
                  onTap: () => onSelectTab(_PackagesTab.templates),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppControlTogglePill(
                  label: 'Subscriptions',
                  icon: Icons.receipt_long_rounded,
                  count: subscriptionCount,
                  selected: selectedTab == _PackagesTab.sold,
                  onTap: () => onSelectTab(_PackagesTab.sold),
                ),
              ),
            ],
          ),
        ),
        if (selectedTab == _PackagesTab.sold) ...[
          const SizedBox(height: 8),
          AppCalendarControlButton(
            label: appDateRangeFilterLabel(selectedDateFilter),
            onTap: onPickDate,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: Row(
              children: [
                Expanded(
                  child: AppControlTogglePill(
                    label: 'Total',
                    count: soldCounts.total,
                    selected: selectedSoldTab == _SoldSubscriptionTab.total,
                    onTap: () => onSelectSoldTab(_SoldSubscriptionTab.total),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppControlTogglePill(
                    label: 'Active',
                    count: soldCounts.active,
                    selected: selectedSoldTab == _SoldSubscriptionTab.active,
                    onTap: () => onSelectSoldTab(_SoldSubscriptionTab.active),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppControlTogglePill(
                    label: 'Replaced',
                    count: soldCounts.replaced,
                    selected: selectedSoldTab == _SoldSubscriptionTab.replaced,
                    onTap: () => onSelectSoldTab(_SoldSubscriptionTab.replaced),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: AppControlTogglePill(
                    label: 'Expired',
                    count: soldCounts.expired,
                    selected: selectedSoldTab == _SoldSubscriptionTab.expired,
                    onTap: () => onSelectSoldTab(_SoldSubscriptionTab.expired),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SoldSubscriptionCounts {
  const _SoldSubscriptionCounts({
    required this.total,
    required this.active,
    required this.replaced,
    required this.expired,
  });

  factory _SoldSubscriptionCounts.from(
    List<ClientSubscriptionSummary> subscriptions,
  ) {
    return _SoldSubscriptionCounts(
      total: subscriptions.length,
      active: subscriptions
          .where((subscription) => subscription.normalizedStatus == 'active')
          .length,
      replaced: subscriptions
          .where((subscription) => subscription.normalizedStatus == 'replaced')
          .length,
      expired: subscriptions
          .where((subscription) => subscription.normalizedStatus == 'expired')
          .length,
    );
  }

  final int total;
  final int active;
  final int replaced;
  final int expired;
}

class _PackagesStatusBanner extends StatelessWidget {
  const _PackagesStatusBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError
            ? AppColors.danger.withValues(alpha: 0.14)
            : AppColors.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isError ? AppColors.danger : AppColors.success).withValues(
            alpha: 0.28,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: isError ? AppColors.danger : AppColors.success,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isError ? AppColors.danger : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackagesLoadingCard extends StatelessWidget {
  const _PackagesLoadingCard({
    this.gymName,
    this.message = 'Loading packages...',
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
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(gymName ?? 'Packages', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyMedium),
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
    this.description = 'Could not load this section.',
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
              'This section opens only inside a gym account.',
              style: theme.textTheme.bodyMedium,
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
    this.title = 'Nothing here yet',
    this.message = 'No records found for this section.',
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
    final accent = _subscriptionAccentColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.18),
                    theme.colorScheme.surfaceContainerHighest,
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.28)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clientName, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          subscription.packageName ?? 'Unknown package',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.ink,
                          ),
                        ),
                        if (clientPhone != null && clientPhone!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(clientPhone!, style: theme.textTheme.bodyMedium),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(status: status),
                ],
              ),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        subscription.replaceComment!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
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
                      child: const Text('Edit start'),
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
      'active' => (AppColors.success, AppColors.canvasStrong, 'Active'),
      'scheduled' => (const Color(0xFF5AA9FF), Colors.white, 'Scheduled'),
      'expired' => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurface,
        'Expired',
      ),
      'cancelled' => (Colors.grey.shade700, Colors.white, 'Cancelled'),
      'replaced' => (AppColors.danger, Colors.white, 'Replaced'),
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
    final gradientColors = _packageGradientColors(package.gradient);
    final previewValue = package.duration ?? visitLimit ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.last.withValues(alpha: 0.24),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    previewValue > 0 ? '$previewValue' : '-',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.name ?? 'Unnamed package',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package.price == null
                            ? 'Price not set'
                            : '${_formatAmount(package.price!)} sum',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        package.description?.trim().isNotEmpty == true
                            ? package.description!.trim()
                            : 'Simple package template',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
                if (package.duration != null)
                  _PackageChip(
                    icon: Icons.calendar_month_rounded,
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
                  label: _packageGenderLabel(package.gender),
                ),
                if (package.freezeEnabled == true)
                  _PackageChip(
                    icon: Icons.ac_unit_rounded,
                    label: 'Freeze ${package.maxFreezeDays ?? 0}',
                  ),
                if ((package.startTime != null &&
                        package.startTime!.isNotEmpty) ||
                    (package.endTime != null && package.endTime!.isNotEmpty))
                  _PackageChip(
                    icon: Icons.schedule_rounded,
                    label:
                        '${package.startTime ?? '--:--'} - ${package.endTime ?? '--:--'}',
                  ),
              ],
            ),
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

Color _subscriptionAccentColor(String status) {
  return switch (status) {
    'active' => AppColors.success,
    'scheduled' => const Color(0xFF5AA9FF),
    'replaced' => AppColors.danger,
    'cancelled' => const Color(0xFF8E99A6),
    _ => const Color(0xFF8B95A2),
  };
}

List<Color> _packageGradientColors(String? gradient) {
  return switch (gradient) {
    'from-emerald-500 to-emerald-700' => const [
      Color(0xFF58D49D),
      Color(0xFF25895B),
    ],
    'from-rose-500 to-rose-700' => const [Color(0xFFFF637F), Color(0xFFC21F4F)],
    'from-sky-500 to-sky-700' => const [Color(0xFF60C8FF), Color(0xFF2B7BCA)],
    'from-purple-500 to-purple-700' => const [
      Color(0xFFC571FF),
      Color(0xFF7C36E1),
    ],
    'from-amber-500 to-amber-700' => const [
      Color(0xFFFFC451),
      Color(0xFFC27E00),
    ],
    _ => const [Color(0xFF7D74FF), Color(0xFF5149E8)],
  };
}

String _packageGenderLabel(String? gender) {
  return switch (gender) {
    'male' => 'Male',
    'female' => 'Female',
    _ => 'All',
  };
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
