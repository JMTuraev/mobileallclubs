import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/client_actions_service.dart';
import '../application/client_detail_providers.dart';
import '../application/clients_providers.dart';
import '../domain/client_detail_models.dart';
import '../domain/client_summary.dart';
import 'start_session_dialog.dart';

enum _ClientsFilter { all, active, passive, online }

extension on _ClientsFilter {
  String get label {
    return switch (this) {
      _ClientsFilter.all => 'All Clients',
      _ClientsFilter.active => 'Active Clients',
      _ClientsFilter.passive => 'Passive Clients',
      _ClientsFilter.online => 'Online Clients',
    };
  }
}

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchController = TextEditingController();
  String? _mutatingClientId;
  _ClientsFilter _selectedFilter = _ClientsFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startSession(GymClientSummary client) async {
    if (_mutatingClientId != null) {
      return;
    }

    final dialogResult = await showStartSessionDialog(
      context,
      clientName: client.fullName,
    );

    if (dialogResult == null || !mounted) {
      return;
    }

    setState(() => _mutatingClientId = client.id);

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
        setState(() => _mutatingClientId = null);
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
    final searchQuery = _searchController.text;
    final canAccessClients = _canAccessClients(session);
    final runtimeStateByClient = _buildClientRuntimeState(
      subscriptions: subscriptions,
      sessions: clientSessions,
    );

    return AppShellBody(
      expandHeight: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: !canAccessClients
          ? _ClientsAccessBlocked(onBack: () => context.go(AppRoutes.app))
          : clientsAsync.when(
              loading: () => _ClientsLoadingCard(gymName: session?.gym?.name),
              error: (error, stackTrace) =>
                  _ClientsErrorCard(message: error.toString()),
              data: (clients) {
                final entries = clients
                    .map(
                      (client) => _ClientListEntry(
                        client: client,
                        runtimeState:
                            runtimeStateByClient[client.id] ??
                            const _ClientRuntimeState(),
                      ),
                    )
                    .toList(growable: false);

                final counts = _buildFilterCounts(entries);
                final matchingEntries = entries
                    .where((entry) => entry.client.matchesSearch(searchQuery))
                    .toList(growable: false);
                final visibleEntries =
                    matchingEntries
                        .where((entry) => entry.matchesFilter(_selectedFilter))
                        .toList()
                      ..sort(_compareClientEntries);

                return Stack(
                  children: [
                    CustomScrollView(
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _ClientsControlsHeaderDelegate(
                            extent: 92,
                            child: _ClientsControlsHeader(
                              searchController: _searchController,
                              searchQuery: searchQuery,
                              selectedFilter: _selectedFilter,
                              counts: counts,
                              onSearchChanged: (_) => setState(() {}),
                              onClearSearch: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              onFilterSelected: (filter) {
                                setState(() => _selectedFilter = filter);
                              },
                              onCreateClient: () =>
                                  context.go(AppRoutes.createClient),
                            ),
                          ),
                        ),
                        if (visibleEntries.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _ClientsEmptyCard(
                                hasSearch: searchQuery.trim().isNotEmpty,
                                filter: _selectedFilter,
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.only(top: 6, bottom: 116),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index.isOdd) {
                                    return Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: _alpha(AppColors.border, 0.42),
                                    );
                                  }

                                  final entry = visibleEntries[index ~/ 2];

                                  return _ClientChatTile(
                                    entry: entry,
                                    isActionBusy:
                                        _mutatingClientId == entry.client.id,
                                    onTap: () => context.go(
                                      AppRoutes.clientDetail(entry.client.id),
                                    ),
                                    onPrimaryAction:
                                        entry.runtimeState.canStartSession
                                        ? () => _startSession(entry.client)
                                        : null,
                                  );
                                },
                                childCount: visibleEntries.isEmpty
                                    ? 0
                                    : visibleEntries.length * 2 - 1,
                              ),
                            ),
                          ),
                        if (kDebugMode)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 16,
                                bottom: 116,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    context.go(AppRoutes.firebaseDiagnostics),
                                icon: const Icon(Icons.developer_mode_rounded),
                                label: const Text(
                                  'Open Developer Firebase Diagnostics',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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

class _ClientsControlsHeader extends StatelessWidget {
  const _ClientsControlsHeader({
    required this.searchController,
    required this.searchQuery,
    required this.selectedFilter,
    required this.counts,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterSelected,
    required this.onCreateClient,
  });

  final TextEditingController searchController;
  final String searchQuery;
  final _ClientsFilter selectedFilter;
  final Map<_ClientsFilter, int> counts;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<_ClientsFilter> onFilterSelected;
  final VoidCallback onCreateClient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: AppLiquidGlass(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 6,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xD8334255), Color(0xC0141B24)],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          style: theme.textTheme.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Search by phone',
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: searchQuery.isEmpty
                            ? const SizedBox(width: 18, height: 18)
                            : IconButton(
                                key: const ValueKey('clear-search'),
                                onPressed: onClearSearch,
                                icon: const Icon(Icons.close_rounded, size: 17),
                                color: AppColors.mutedInk,
                                splashRadius: 16,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 48,
              width: 48,
              child: _FloatingAddClientButton(onTap: onCreateClient),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 30,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) {
              final filter = _ClientsFilter.values[index];

              return _ClientsFilterPill(
                label: filter.label,
                count: counts[filter] ?? 0,
                selected: filter == selectedFilter,
                onTap: () => onFilterSelected(filter),
              );
            },
            separatorBuilder: (context, index) => const SizedBox(width: 4),
            itemCount: _ClientsFilter.values.length,
          ),
        ),
      ],
    );
  }
}

class _ClientsControlsHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ClientsControlsHeaderDelegate({
    required this.child,
    required this.extent,
  });

  final Widget child;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: _alpha(AppColors.canvasStrong, overlapsContent ? 0.96 : 0.84),
      padding: const EdgeInsets.only(top: 3, bottom: 3),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _ClientsControlsHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.extent != extent;
  }
}

class _ClientsFilterPill extends StatelessWidget {
  const _ClientsFilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xCCF8FBFF), Color(0x80DDE5F0)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xA628394A), Color(0x88141D26)],
                  ),
            border: Border.all(
              color: selected
                  ? const Color(0x88FFFFFF)
                  : _alpha(AppColors.border, 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.canvasStrong : AppColors.ink,
                  fontSize: 10.4,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? _alpha(Colors.white, 0.2)
                      : _alpha(Colors.white, 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 9.8,
                    color: selected
                        ? AppColors.canvasStrong
                        : _alpha(Colors.white, 0.92),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientChatTile extends StatelessWidget {
  const _ClientChatTile({
    required this.entry,
    required this.onTap,
    required this.onPrimaryAction,
    required this.isActionBusy,
  });

  final _ClientListEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onPrimaryAction;
  final bool isActionBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = entry.client;
    final runtimeState = entry.runtimeState;
    final badgeColor = _statusBadgeColor(runtimeState);
    final phoneLabel = _formatPhone(client.phone) ?? client.phone;
    final actionLabel = runtimeState.primaryActionLabel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 2, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ClientAvatar(
                initials: client.initials,
                imageUrl: client.imageUrl,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      phoneLabel ?? 'Phone not available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: runtimeState.isOnline
                            ? _alpha(AppColors.ink, 0.88)
                            : AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (actionLabel != null || runtimeState.keyLabel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: runtimeState.keyLabel != null
                          ? _LockerBadge(value: runtimeState.keyLabel!)
                          : _PrimaryActionButton(
                              label: actionLabel!,
                              isBusy: isActionBusy,
                              onTap: onPrimaryAction,
                            ),
                    ),
                  _ClientStatusBadge(
                    label: _visitBadgeLabel(runtimeState),
                    color: badgeColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar({required this.initials, required this.imageUrl});

  final String initials;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 56,
      height: 56,
      child: CircleAvatar(
        radius: 27,
        backgroundColor: const Color(0xFF4B647F),
        backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
        child: imageUrl == null
            ? Text(
                initials,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
    );
  }
}

class _BadgeFrame extends StatelessWidget {
  const _BadgeFrame({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    this.onTap,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: const BoxConstraints(minHeight: 22, minWidth: 60),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Center(child: child),
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

class _LockerBadge extends StatelessWidget {
  const _LockerBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _BadgeFrame(
      backgroundColor: _alpha(AppColors.accent, 0.18),
      borderColor: _alpha(AppColors.accent, 0.46),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_rounded, size: 11.5, color: AppColors.accent),
          const SizedBox(width: 3),
          Text(
            value,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.accent,
              fontSize: 10.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientStatusBadge extends StatelessWidget {
  const _ClientStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _BadgeFrame(
      backgroundColor: _alpha(color, 0.18),
      borderColor: _alpha(color, 0.38),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.isBusy,
    required this.onTap,
  });

  final String label;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: _BadgeFrame(
        onTap: isBusy ? null : onTap,
        backgroundColor: _alpha(AppColors.primary, 0.16),
        borderColor: _alpha(AppColors.primary, 0.4),
        child: isBusy
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.key_rounded, size: 14, color: AppColors.primary),
      ),
    );
  }
}

class _FloatingAddClientButton extends StatelessWidget {
  const _FloatingAddClientButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppLiquidGlass(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF8FBFF), Color(0xD6DEE8F1)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.canvasStrong,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

class _ClientsLoadingCard extends StatelessWidget {
  const _ClientsLoadingCard({this.gymName});

  final String? gymName;

  @override
  Widget build(BuildContext context) {
    return _StatusPanel(
      title: gymName ?? 'Clients',
      subtitle: 'Loading current gym clients...',
      child: const Padding(
        padding: EdgeInsets.only(top: 16),
        child: LinearProgressIndicator(),
      ),
    );
  }
}

class _ClientsErrorCard extends StatelessWidget {
  const _ClientsErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _StatusPanel(
      title: 'Clients unavailable',
      subtitle: 'The clients query failed for the current gym.',
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
        ),
      ),
    );
  }
}

class _ClientsEmptyCard extends StatelessWidget {
  const _ClientsEmptyCard({required this.hasSearch, required this.filter});

  final bool hasSearch;
  final _ClientsFilter filter;

  @override
  Widget build(BuildContext context) {
    final title = hasSearch
        ? 'No matching clients'
        : switch (filter) {
            _ClientsFilter.active => 'No active clients',
            _ClientsFilter.passive => 'No passive clients',
            _ClientsFilter.online => 'No online clients',
            _ClientsFilter.all => 'No clients yet',
          };

    final subtitle = hasSearch
        ? 'Try another phone number or client name.'
        : switch (filter) {
            _ClientsFilter.active =>
              'Active package holders and online members will appear here.',
            _ClientsFilter.passive =>
              'Clients without an active package are shown in this tab.',
            _ClientsFilter.online =>
              'Members with an active session will appear at the top.',
            _ClientsFilter.all =>
              'No active client documents were returned for this gym.',
          };

    return _StatusPanel(title: title, subtitle: subtitle);
  }
}

class _ClientsAccessBlocked extends StatelessWidget {
  const _ClientsAccessBlocked({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return _StatusPanel(
      title: 'Clients unavailable',
      subtitle:
          'This module is available only for owner or staff accounts with a resolved gym context.',
      action: FilledButton.icon(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('Back to account'),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.title,
    required this.subtitle,
    this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[
      Text(title, style: theme.textTheme.headlineSmall),
      const SizedBox(height: 10),
      Text(subtitle, style: theme.textTheme.bodyLarge),
    ];

    if (child != null) {
      children.add(child!);
    }

    if (action != null) {
      children.add(const SizedBox(height: 18));
      children.add(action!);
    }

    return Center(
      child: AppLiquidGlass(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xD8243140), Color(0xC0131B24)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _ClientListEntry {
  const _ClientListEntry({required this.client, required this.runtimeState});

  final GymClientSummary client;
  final _ClientRuntimeState runtimeState;

  bool matchesFilter(_ClientsFilter filter) {
    return switch (filter) {
      _ClientsFilter.all => true,
      _ClientsFilter.active => runtimeState.isActiveClient,
      _ClientsFilter.passive => runtimeState.isPassiveClient,
      _ClientsFilter.online => runtimeState.isOnline,
    };
  }
}

class _ClientRuntimeState {
  const _ClientRuntimeState({
    this.activeSubscription,
    this.scheduledSubscription,
    this.activeSession,
    this.latestSession,
  });

  final ClientSubscriptionSummary? activeSubscription;
  final ClientSubscriptionSummary? scheduledSubscription;
  final ClientSessionSummary? activeSession;
  final ClientSessionSummary? latestSession;

  bool get isOnline => activeSession != null;

  bool get isActiveClient => isOnline || activeSubscription != null;

  bool get isPassiveClient => !isActiveClient;

  bool get canStartSession {
    if (activeSubscription == null || activeSession != null) {
      return false;
    }

    final visitLimit = activeSubscription!.visitLimit;
    final remainingVisits = activeSubscription!.remainingVisits ?? 0;

    return visitLimit == null || remainingVisits > 0;
  }

  String? get primaryActionLabel {
    if (canStartSession) {
      return 'Give key';
    }

    return null;
  }

  String? get keyLabel => activeSession?.locker;

  DateTime? get sortDate {
    return activeSession?.effectiveDate ??
        latestSession?.effectiveDate ??
        activeSubscription?.startDate ??
        activeSubscription?.createdAt ??
        scheduledSubscription?.startDate ??
        scheduledSubscription?.createdAt;
  }
}

Map<String, _ClientRuntimeState> _buildClientRuntimeState({
  required List<ClientSubscriptionSummary> subscriptions,
  required List<ClientSessionSummary> sessions,
}) {
  final activeSubscriptions = <String, ClientSubscriptionSummary>{};
  final scheduledSubscriptions = <String, ClientSubscriptionSummary>{};
  final activeSessions = <String, ClientSessionSummary>{};
  final latestSessions = <String, ClientSessionSummary>{};

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
    if (clientId == null || clientId.isEmpty) {
      continue;
    }

    final latest = latestSessions[clientId];
    if (_isSessionNewer(session, latest)) {
      latestSessions[clientId] = session;
    }

    if (session.status != 'active') {
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
    ...latestSessions.keys,
  };

  return {
    for (final clientId in allClientIds)
      clientId: _ClientRuntimeState(
        activeSubscription: activeSubscriptions[clientId],
        scheduledSubscription: scheduledSubscriptions[clientId],
        activeSession: activeSessions[clientId],
        latestSession: latestSessions[clientId],
      ),
  };
}

Map<_ClientsFilter, int> _buildFilterCounts(List<_ClientListEntry> entries) {
  return {
    _ClientsFilter.all: entries.length,
    _ClientsFilter.active: entries
        .where((entry) => entry.runtimeState.isActiveClient)
        .length,
    _ClientsFilter.passive: entries
        .where((entry) => entry.runtimeState.isPassiveClient)
        .length,
    _ClientsFilter.online: entries
        .where((entry) => entry.runtimeState.isOnline)
        .length,
  };
}

int _compareClientEntries(_ClientListEntry first, _ClientListEntry second) {
  final priorityCompare = _sortPriority(
    first.runtimeState,
  ).compareTo(_sortPriority(second.runtimeState));
  if (priorityCompare != 0) {
    return priorityCompare;
  }

  final firstDate =
      first.runtimeState.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
  final secondDate =
      second.runtimeState.sortDate ?? DateTime.fromMillisecondsSinceEpoch(0);
  final dateCompare = secondDate.compareTo(firstDate);
  if (dateCompare != 0) {
    return dateCompare;
  }

  return first.client.fullName.toLowerCase().compareTo(
    second.client.fullName.toLowerCase(),
  );
}

int _sortPriority(_ClientRuntimeState state) {
  if (state.isOnline) {
    return 0;
  }

  if (state.isActiveClient) {
    return 1;
  }

  return 2;
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

Color _statusBadgeColor(_ClientRuntimeState state) {
  if (state.isOnline) {
    return AppColors.success;
  }

  if (state.isActiveClient) {
    return AppColors.accent;
  }

  return const Color(0xFF9AA9B8);
}

String _visitBadgeLabel(_ClientRuntimeState state) {
  if (state.isOnline) {
    final activeDate = state.activeSession?.effectiveDate;
    if (activeDate == null) {
      return 'Hozir';
    }

    return _formatElapsedSince(activeDate);
  }

  if (state.activeSubscription != null) {
    return 'Active';
  }

  return 'Passive';
}

String _formatElapsedSince(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  final minutes = difference.inMinutes;
  if (minutes <= 1) {
    return '1 min';
  }

  if (minutes < 60) {
    return '$minutes min';
  }

  final hours = difference.inHours;
  if (hours < 24) {
    return '$hours soat';
  }

  final days = difference.inDays;
  return '$days kun';
}

String? _formatPhone(String? phone) {
  if (phone == null || phone.trim().isEmpty) {
    return null;
  }

  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 9) {
    return phone;
  }

  final localDigits = digits.substring(digits.length - 9);
  return '${localDigits.substring(0, 2)} '
      '${localDigits.substring(2, 5)} '
      '${localDigits.substring(5, 7)} '
      '${localDigits.substring(7, 9)}';
}
