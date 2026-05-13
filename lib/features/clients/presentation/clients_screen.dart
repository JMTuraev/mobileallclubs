import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/developer_tools.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_client_list_item.dart';
import '../../../core/widgets/app_data_chip.dart';
import '../../../core/utils/phone_launcher.dart';
import '../../../core/widgets/app_control_widgets.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
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

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);
const double _clientTileExtentEstimate = 94;
const double _clientsControlsHeaderExtent = 114;
const double _clientsFilterNavHeight = 50;

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key, this.highlightClientId});

  final String? highlightClientId;

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _searchController = TextEditingController();
  final _listController = ScrollController();
  final Map<String, GlobalKey> _tileKeys = <String, GlobalKey>{};
  String? _mutatingClientId;
  String? _highlightedClientId;
  String? _handledHighlightClientId;
  _ClientsFilter _selectedFilter = _ClientsFilter.all;

  @override
  void initState() {
    super.initState();
    _prepareHighlightFilters();
  }

  @override
  void didUpdateWidget(covariant ClientsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightClientId != oldWidget.highlightClientId) {
      _prepareHighlightFilters();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  void _prepareHighlightFilters() {
    final targetId = widget.highlightClientId?.trim();
    if (targetId == null || targetId.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final needsReset =
          _selectedFilter != _ClientsFilter.all ||
          _searchController.text.trim().isNotEmpty;

      if (!needsReset) {
        return;
      }

      _searchController.clear();
      setState(() => _selectedFilter = _ClientsFilter.all);
    });
  }

  void _scrollResultsToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_listController.hasClients ||
          _listController.offset <= 8) {
        return;
      }

      _listController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _handleSearchChanged(String _) {
    setState(() {});
    _scrollResultsToTop();
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) {
      return;
    }

    _searchController.clear();
    setState(() {});
    _scrollResultsToTop();
  }

  void _selectFilter(_ClientsFilter filter) {
    final nextFilter = filter == _selectedFilter ? _ClientsFilter.all : filter;
    if (nextFilter == _selectedFilter) {
      return;
    }

    setState(() => _selectedFilter = nextFilter);
    _scrollResultsToTop();
  }

  void _queueHighlightedClientReveal(List<_ClientListEntry> visibleEntries) {
    final targetId = widget.highlightClientId?.trim();
    if (targetId == null ||
        targetId.isEmpty ||
        _handledHighlightClientId == targetId) {
      return;
    }

    final targetIndex = visibleEntries.indexWhere(
      (entry) => entry.client.id == targetId,
    );
    if (targetIndex == -1) {
      return;
    }

    _handledHighlightClientId = targetId;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      setState(() => _highlightedClientId = targetId);

      if (_listController.hasClients) {
        final rawOffset = targetIndex * _clientTileExtentEstimate;
        final maxOffset = _listController.position.maxScrollExtent;
        final targetOffset = rawOffset.clamp(0.0, maxOffset).toDouble();

        if ((_listController.offset - targetOffset).abs() > 24) {
          await _listController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
          );
        }
      }

      for (var attempt = 0; attempt < 6; attempt++) {
        if (!mounted) {
          return;
        }

        await Future<void>.delayed(const Duration(milliseconds: 90));
        if (!mounted) {
          return;
        }

        final tileContext = _tileKeys[targetId]?.currentContext;
        if (tileContext == null || !tileContext.mounted) {
          continue;
        }

        await Scrollable.ensureVisible(
          tileContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
        break;
      }

      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted || _highlightedClientId != targetId) {
        return;
      }

      setState(() => _highlightedClientId = null);
    });
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
    String? feedbackMessage;

    try {
      await ref
          .read(clientActionsServiceProvider)
          .startSession(
            clientId: client.id,
            lockerNumber: dialogResult.lockerNumber,
          );
      feedbackMessage = '${client.fullName} session started.';
    } catch (error) {
      feedbackMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() => _mutatingClientId = null);
        if (feedbackMessage != null) {
          showAppSnackBar(context, feedbackMessage);
        }
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

  void _openPosForClient(_ClientListEntry entry) {
    final activeSession = entry.runtimeState.activeSession;
    if (activeSession == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('POS opens only for clients with an active session.'),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    context.go(AppRoutes.barPos(entry.client.id, activeSession.id));
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
      padding: appControlsPagePadding,
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

                final hasSearch = searchQuery.trim().isNotEmpty;
                final matchingEntries = entries
                    .where((entry) => entry.client.matchesSearch(searchQuery))
                    .toList(growable: false);
                final counts = _buildFilterCounts(matchingEntries);
                final visibleEntries =
                    matchingEntries
                        .where((entry) => entry.matchesFilter(_selectedFilter))
                        .toList()
                      ..sort(_compareClientEntries);
                _queueHighlightedClientReveal(visibleEntries);

                if (visibleEntries.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ClientsControlsHeader(
                        searchController: _searchController,
                        searchQuery: searchQuery,
                        selectedFilter: _selectedFilter,
                        counts: counts,
                        onSearchChanged: _handleSearchChanged,
                        onClearSearch: _clearSearch,
                        onFilterSelected: _selectFilter,
                        onCreateClient: () =>
                            context.go(AppRoutes.createClient),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: _ClientsEmptyState(
                          hasSearch: hasSearch,
                          filter: _selectedFilter,
                        ),
                      ),
                      if (showDeveloperDiagnosticsShortcut)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 116),
                          child: OutlinedButton.icon(
                            onPressed: () => openDeveloperDiagnostics(context),
                            icon: const Icon(Icons.developer_mode_rounded),
                            label: const Text(
                              'Open Developer Firebase Diagnostics',
                            ),
                          ),
                        ),
                    ],
                  );
                }

                return Stack(
                  children: [
                    CustomScrollView(
                      controller: _listController,
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: AppControlsSliverHeaderDelegate(
                            extent: _clientsControlsHeaderExtent,
                            child: _ClientsControlsHeader(
                              searchController: _searchController,
                              searchQuery: searchQuery,
                              selectedFilter: _selectedFilter,
                              counts: counts,
                              onSearchChanged: _handleSearchChanged,
                              onClearSearch: _clearSearch,
                              onFilterSelected: _selectFilter,
                              onCreateClient: () =>
                                  context.go(AppRoutes.createClient),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 6, bottom: 116),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              if (index.isOdd) {
                                return Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: _alpha(AppColors.border, 0.42),
                                );
                              }

                              final entry = visibleEntries[index ~/ 2];
                              final tileKey =
                                  entry.client.id == widget.highlightClientId
                                  ? (_tileKeys[entry.client.id] ??= GlobalKey())
                                  : null;

                              return _ClientChatTile(
                                key: tileKey,
                                entry: entry,
                                isHighlighted:
                                    entry.client.id == _highlightedClientId,
                                isActionBusy:
                                    _mutatingClientId == entry.client.id,
                                onOpenProfile: () => context.go(
                                  AppRoutes.clientDetail(entry.client.id),
                                ),
                                onPhoneTap: entry.client.phone == null
                                    ? null
                                    : () =>
                                          _callClientPhone(entry.client.phone),
                                onPrimaryAction:
                                    entry.runtimeState.canStartSession
                                    ? () => _startSession(entry.client)
                                    : null,
                                onSwipeToPos:
                                    entry.runtimeState.activeSession != null
                                    ? () => _openPosForClient(entry)
                                    : null,
                              );
                            }, childCount: visibleEntries.length * 2 - 1),
                          ),
                        ),
                        if (showDeveloperDiagnosticsShortcut)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 16,
                                bottom: 116,
                              ),
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    openDeveloperDiagnostics(context),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppGlassSearchField(
                controller: searchController,
                onChanged: onSearchChanged,
                onClear: onClearSearch,
                clearVisible: searchQuery.isNotEmpty,
                hintText: 'Search by phone number',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 8),
            AppGlassIconButton(
              icon: Icons.person_add_alt_1_rounded,
              iconColor: Colors.white,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.accent],
              ),
              onTap: onCreateClient,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ClientsFilterNav(
          selectedFilter: selectedFilter,
          counts: counts,
          onFilterSelected: onFilterSelected,
        ),
      ],
    );
  }
}

class _ClientsFilterNav extends StatelessWidget {
  const _ClientsFilterNav({
    required this.selectedFilter,
    required this.counts,
    required this.onFilterSelected,
  });

  final _ClientsFilter selectedFilter;
  final Map<_ClientsFilter, int> counts;
  final ValueChanged<_ClientsFilter> onFilterSelected;

  static const _filters = <_ClientsFilter>[
    _ClientsFilter.all,
    _ClientsFilter.online,
    _ClientsFilter.active,
    _ClientsFilter.passive,
  ];

  @override
  Widget build(BuildContext context) {
    final tabWidth = MediaQuery.sizeOf(context).width * 0.46;

    return Container(
      height: _clientsFilterNavHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _alpha(AppColors.border, 0.82)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var index = 0; index < _filters.length; index++) ...[
              SizedBox(
                width: tabWidth,
                child: _ClientsFilterNavItem(
                  label: _labelFor(_filters[index]),
                  count: counts[_filters[index]] ?? 0,
                  selected: _filters[index] == selectedFilter,
                  onTap: () => onFilterSelected(_filters[index]),
                ),
              ),
              if (index != _filters.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  String _labelFor(_ClientsFilter filter) {
    return switch (filter) {
      _ClientsFilter.all => 'All',
      _ClientsFilter.online => 'Online',
      _ClientsFilter.active => 'Active',
      _ClientsFilter.passive => 'Passive',
    };
  }
}

class _ClientsFilterNavItem extends StatelessWidget {
  const _ClientsFilterNavItem({
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
    final labelStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 14.5,
      fontWeight: FontWeight.w700,
      color: selected ? AppColors.primary : AppColors.ink,
      letterSpacing: -0.15,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: _clientsFilterNavHeight - 8,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, maxLines: 1, softWrap: false, style: labelStyle),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                constraints: const BoxConstraints(minWidth: 42),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : AppColors.panelRaised,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.mutedInk,
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
    super.key,
    required this.entry,
    required this.onOpenProfile,
    required this.onPrimaryAction,
    required this.isActionBusy,
    required this.isHighlighted,
    this.onPhoneTap,
    this.onSwipeToPos,
  });

  final _ClientListEntry entry;
  final VoidCallback onOpenProfile;
  final VoidCallback? onPrimaryAction;
  final bool isActionBusy;
  final bool isHighlighted;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onSwipeToPos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final client = entry.client;
    final runtimeState = entry.runtimeState;
    final phoneLabel = _formatPhone(client.phone) ?? client.phone;
    final actionLabel = runtimeState.primaryActionLabel;
    final hasTrailingBadge =
        actionLabel != null || runtimeState.keyLabel != null;
    final subtitle = phoneLabel != null
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPhoneTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  phoneLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: _alpha(AppColors.primary, 0.72),
                  ),
                ),
              ),
            ),
          )
        : Text(
            'Phone not available',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: runtimeState.isOnline
                  ? _alpha(AppColors.ink, 0.88)
                  : AppColors.mutedInk,
            ),
          );
    final trailing = hasTrailingBadge
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (runtimeState.keyLabel != null)
                _LockerBadge(value: runtimeState.keyLabel!)
              else
                _PrimaryActionButton(
                  label: actionLabel!,
                  isBusy: isActionBusy,
                  onTap: onPrimaryAction,
                ),
            ],
          )
        : null;
    final tileContent = AppClientListItem(
      leading: AppClientPresenceAvatar(
        label: client.fullName,
        fallback: client.initials,
        imageUrl: client.imageUrl,
        isOnline: runtimeState.isOnline,
      ),
      title: client.fullName,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onOpenProfile,
      highlighted: isHighlighted,
    );

    if (onSwipeToPos == null) {
      return tileContent;
    }

    return Dismissible(
      key: ValueKey('client-pos-${entry.client.id}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const <DismissDirection, double>{
        DismissDirection.startToEnd: 0.28,
      },
      confirmDismiss: (_) async {
        onSwipeToPos!();
        return false;
      },
      background: const _ClientPosSwipeBackground(),
      child: tileContent,
    );
  }
}

class _ClientPosSwipeBackground extends StatelessWidget {
  const _ClientPosSwipeBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _alpha(AppColors.primary, 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _alpha(AppColors.primary, 0.38)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _alpha(AppColors.primary, 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POS Menu',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Swipe to open',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedInk,
                ),
              ),
            ],
          ),
        ],
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
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    this.constraints = const BoxConstraints(minHeight: 22, minWidth: 60),
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: constraints,
      padding: padding,
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
    return AppDataChip(
      icon: Icons.key_rounded,
      label: value,
      tone: AppChipTone.warning,
      emphasis: true,
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isBusy ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 28,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: isBusy
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: AppColors.primaryDeep,
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

class _ClientsEmptyState extends StatelessWidget {
  const _ClientsEmptyState({required this.hasSearch, required this.filter});

  final bool hasSearch;
  final _ClientsFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = hasSearch
        ? 'No matching clients'
        : switch (filter) {
            _ClientsFilter.active => 'No active clients',
            _ClientsFilter.passive => 'No passive clients',
            _ClientsFilter.online => 'No online clients',
            _ClientsFilter.all => 'No clients yet',
          };

    final subtitle = hasSearch
        ? 'Try another phone number or clear the search.'
        : switch (filter) {
            _ClientsFilter.active =>
              'Active members will appear here once sessions or packages are added.',
            _ClientsFilter.passive =>
              'Clients without an active package will appear in this section.',
            _ClientsFilter.online =>
              'Members with an active session will appear here.',
            _ClientsFilter.all =>
              'Add your first client to start building the gym roster.',
          };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/illustrations/clients_empty.svg',
              width: 220,
              height: 180,
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.mutedInk,
              ),
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
        borderRadius: BorderRadius.circular(24),
        gradient: AppGradients.panel,
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
