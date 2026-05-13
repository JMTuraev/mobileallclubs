import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/developer_tools.dart';
import '../../../core/localization/app_currency.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_client_list_item.dart';
import '../../../core/widgets/app_control_widgets.dart';
import '../../../core/widgets/app_date_range_filter_sheet.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bar/application/bar_providers.dart';
import '../../bar/domain/bar_session_check_summary.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../../clients/application/client_actions_service.dart';
import '../../clients/application/clients_providers.dart';
import '../../clients/domain/client_summary.dart';
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
  AppDateRangeFilter _selectedDateFilter = AppDateRangeFilter.today(
    DateTime.now(),
  );
  _SessionViewFilter _selectedStatusFilter = _SessionViewFilter.online;
  String? _expandedSessionId;
  bool _hasInteractedWithExpansion = false;
  String? _endingSessionId;
  final Map<String, String> _selectedTabsBySessionId = <String, String>{};

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

  Future<void> _pickDateFilter() async {
    final picked = await showAppDateRangeFilterSheet(
      context: context,
      title: 'Sessions range',
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

  void _selectStatusFilter(_SessionViewFilter filter) {
    setState(() {
      _selectedStatusFilter = filter;
    });
  }

  void _toggleSession(String sessionId, String? effectiveExpandedSessionId) {
    setState(() {
      _hasInteractedWithExpansion = true;
      _expandedSessionId = effectiveExpandedSessionId == sessionId
          ? null
          : sessionId;
    });
  }

  void _selectSessionTab(String sessionId, String tabId) {
    setState(() {
      _selectedTabsBySessionId[sessionId] = tabId;
    });
  }

  void _showSessionNotice(String message, {required bool isError}) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: isError
            ? theme.colorScheme.error
            : const Color(0xFF21362B),
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Future<void> _showSessionBlockedDialog(String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bar check yopilmagan'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _sessionEndBlockedMessage(
    GymSessionSummary session,
    String clientLabel,
  ) async {
    final checks = await ref.read(barSessionChecksProvider(session.id).future);
    final message = buildSessionEndBlockedMessage(clientLabel, checks);
    if (message.trim().isEmpty) {
      return null;
    }

    return message;
  }

  Future<void> _endSession(
    GymSessionSummary session,
    String resolvedClientName,
  ) async {
    if (_endingSessionId != null) {
      return;
    }

    final clientLabel = resolvedClientName.trim().isEmpty
        ? 'Session'
        : resolvedClientName.trim();

    setState(() {
      _endingSessionId = session.id;
    });

    try {
      final blockedMessage = await _sessionEndBlockedMessage(
        session,
        clientLabel,
      );
      if (!mounted) {
        return;
      }
      if (blockedMessage != null) {
        await _showSessionBlockedDialog(blockedMessage);
        return;
      }

      final shouldEnd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End session'),
          content: Text(
            'End the active session for $clientLabel? This follows the production endSession callable and may consume one remaining visit.',
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
          .endSession(sessionId: session.id);

      if (!mounted) {
        return;
      }

      final debtSuffix = result.barDebt != null && result.barDebt! > 0
          ? ' Bar debt: ${_formatMoney(result.barDebt!, withUnit: true)}.'
          : '';

      _showSessionNotice(
        '$clientLabel session ended.$debtSuffix',
        isError: false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showSessionNotice(_normalizeErrorMessage(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _endingSessionId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(appCurrencyProvider);
    final bootstrapState = ref.watch(bootstrapControllerProvider);
    final session = bootstrapState.session;
    final filteredSessionsAsync = ref.watch(
      filteredGymSessionsProvider(widget.clientId),
    );
    final clientsAsync = ref.watch(currentGymClientsStreamProvider);
    final clients = clientsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <GymClientSummary>[],
    );
    final clientsById = <String, GymClientSummary>{
      for (final client in clients) client.id: client,
    };
    final isNestedClientFlow = widget.clientId?.trim().isNotEmpty == true;
    return AppShellBody(
      padding: appControlsPagePadding,
      child: !_canAccessSessions(session)
          ? _SessionsAccessBlocked(
              onBack: () => context.go(
                isNestedClientFlow
                    ? AppRoutes.clientDetail(widget.clientId!)
                    : AppRoutes.app,
              ),
            )
          : CustomScrollView(
              slivers: [
                if (isNestedClientFlow)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        children: [
                          _NestedClientSessionsBanner(
                            onBack: () => context.go(
                              AppRoutes.clientDetail(widget.clientId!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ...filteredSessionsAsync.when(
                  loading: () => [
                    SliverToBoxAdapter(
                      child: _SessionsLoadingCard(gymName: session?.gym?.name),
                    ),
                  ],
                  error: (error, stackTrace) => [
                    SliverToBoxAdapter(
                      child: _SessionsErrorCard(message: error.toString()),
                    ),
                  ],
                  data: (sessions) {
                    final dateFilteredSessions =
                        (_selectedDateFilter.preset !=
                                  AppDateRangeFilterPreset.allTime
                              ? sessions
                                    .where(
                                      (session) => _matchesSelectedDateFilter(
                                        session,
                                        _selectedDateFilter,
                                      ),
                                    )
                                    .toList()
                              : sessions.toList())
                          ..sort(_compareSessions);
                    final analytics = _SessionAnalytics.fromSessions(
                      dateFilteredSessions,
                    );
                    final visibleSessions = dateFilteredSessions
                        .where(
                          (session) => _matchesSessionViewFilter(
                            session,
                            _selectedStatusFilter,
                          ),
                        )
                        .toList(growable: false);
                    final effectiveExpandedSessionId =
                        _effectiveExpandedSessionId(
                          sessions: visibleSessions,
                          isNestedClientFlow: isNestedClientFlow,
                        );

                    return [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: AppControlsSliverHeaderDelegate(
                          extent: appControlsHeaderExtent,
                          child: _SessionsHeaderCard(
                            selectedDateFilter: _selectedDateFilter,
                            analytics: analytics,
                            selectedFilter: _selectedStatusFilter,
                            onPickDate: _pickDateFilter,
                            onSelectFilter: _selectStatusFilter,
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: visibleSessions.isEmpty
                            ? _SessionsEmptyCard(
                                dateFilter: _selectedDateFilter,
                              )
                            : _SessionsListCard(
                                sessions: visibleSessions,
                                expandedSessionId: effectiveExpandedSessionId,
                                endingSessionId: _endingSessionId,
                                clientsById: clientsById,
                                selectedTabsBySessionId:
                                    _selectedTabsBySessionId,
                                onToggleSession: (sessionId) => _toggleSession(
                                  sessionId,
                                  effectiveExpandedSessionId,
                                ),
                                onSelectTab: _selectSessionTab,
                                onEndSession: _endSession,
                              ),
                      ),
                    ];
                  },
                ),
                if (showDeveloperDiagnosticsShortcut)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => openDeveloperDiagnostics(context),
                        icon: const Icon(Icons.developer_mode_rounded),
                        label: const Text(
                          'Open Developer Firebase Diagnostics',
                        ),
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 116)),
              ],
            ),
    );
  }

  String? _effectiveExpandedSessionId({
    required List<GymSessionSummary> sessions,
    required bool isNestedClientFlow,
  }) {
    if (_hasInteractedWithExpansion) {
      return _expandedSessionId;
    }

    if (isNestedClientFlow && sessions.isNotEmpty) {
      return sessions.first.id;
    }

    return _expandedSessionId;
  }
}

class _SessionsHeaderCard extends StatelessWidget {
  const _SessionsHeaderCard({
    required this.selectedDateFilter,
    required this.analytics,
    required this.selectedFilter,
    required this.onPickDate,
    required this.onSelectFilter,
  });

  final AppDateRangeFilter selectedDateFilter;
  final _SessionAnalytics analytics;
  final _SessionViewFilter selectedFilter;
  final VoidCallback onPickDate;
  final ValueChanged<_SessionViewFilter> onSelectFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                  label: 'Online',
                  icon: Icons.wifi_tethering_rounded,
                  count: analytics.onlineCount,
                  selected: selectedFilter == _SessionViewFilter.online,
                  onTap: () => onSelectFilter(_SessionViewFilter.online),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppControlTogglePill(
                  label: 'Completed',
                  icon: Icons.check_circle_outline_rounded,
                  count: analytics.closedCount,
                  selected: selectedFilter == _SessionViewFilter.completed,
                  onTap: () => onSelectFilter(_SessionViewFilter.completed),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppControlTogglePill(
                  label: 'All',
                  icon: Icons.history_rounded,
                  count: analytics.totalCount,
                  selected: selectedFilter == _SessionViewFilter.all,
                  onTap: () => onSelectFilter(_SessionViewFilter.all),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NestedClientSessionsBanner extends StatelessWidget {
  const _NestedClientSessionsBanner({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: _sessionPanelDecoration(),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.person_search_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Client sessions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SessionControlButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onTap: onBack,
          ),
        ],
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

class _SessionsLoadingCard extends StatelessWidget {
  const _SessionsLoadingCard({this.gymName});

  final String? gymName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: _sessionPanelDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            gymName ?? 'Sessions',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
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

    return Container(
      decoration: _sessionPanelDecoration(
        tone: _SessionTone.danger,
        outlined: true,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sessions unavailable',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _sessionAlpha(theme.colorScheme.error, 0.94),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsEmptyCard extends StatelessWidget {
  const _SessionsEmptyCard({required this.dateFilter});

  final AppDateRangeFilter dateFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: _sessionPanelDecoration(),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No sessions found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateFilter.preset == AppDateRangeFilterPreset.allTime
                ? 'No visible sessions in the current range.'
                : formatAppDateRangeLong(dateFilter.from, dateFilter.to),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _sessionAlpha(AppColors.secondary, 0.86),
            ),
          ),
        ],
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

    return Container(
      decoration: _sessionPanelDecoration(
        tone: _SessionTone.warning,
        outlined: true,
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sessions unavailable',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Owner yoki staff gym context bilan kirganda ochiladi.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _sessionAlpha(AppColors.secondary, 0.86),
            ),
          ),
          const SizedBox(height: 14),
          _SessionControlButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onTap: onBack,
            expanded: true,
          ),
        ],
      ),
    );
  }
}

class _SessionsListCard extends StatelessWidget {
  const _SessionsListCard({
    required this.sessions,
    required this.expandedSessionId,
    required this.endingSessionId,
    required this.clientsById,
    required this.selectedTabsBySessionId,
    required this.onToggleSession,
    required this.onSelectTab,
    required this.onEndSession,
  });

  final List<GymSessionSummary> sessions;
  final String? expandedSessionId;
  final String? endingSessionId;
  final Map<String, GymClientSummary> clientsById;
  final Map<String, String> selectedTabsBySessionId;
  final ValueChanged<String> onToggleSession;
  final void Function(String sessionId, String tabId) onSelectTab;
  final void Function(GymSessionSummary session, String clientName)
  onEndSession;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var index = 0; index < sessions.length; index++) {
      final session = sessions[index];
      final resolvedClientName = _resolvedSessionClientName(
        session,
        clientsById,
      );

      if (index > 0) {
        children.add(const SizedBox(height: 12));
      }

      children.add(
        _SessionEntryCard(
          index: index,
          session: session,
          clientName: resolvedClientName,
          clientMeta: _resolvedSessionClientMeta(session, clientsById),
          clientImageUrl: _resolvedSessionClientImageUrl(session, clientsById),
          expanded: expandedSessionId == session.id,
          isEnding: endingSessionId == session.id,
          selectedTabId:
              selectedTabsBySessionId[session.id] ??
              _defaultTabForSession(session),
          onToggle: () => onToggleSession(session.id),
          onSelectTab: (tabId) => onSelectTab(session.id, tabId),
          onEndSession: session.isActive
              ? () => onEndSession(session, resolvedClientName)
              : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _SessionEntryCard extends ConsumerWidget {
  const _SessionEntryCard({
    required this.index,
    required this.session,
    required this.clientName,
    required this.clientMeta,
    required this.clientImageUrl,
    required this.expanded,
    required this.isEnding,
    required this.selectedTabId,
    required this.onToggle,
    required this.onSelectTab,
    required this.onEndSession,
  });

  final int index;
  final GymSessionSummary session;
  final String clientName;
  final String? clientMeta;
  final String? clientImageUrl;
  final bool expanded;
  final bool isEnding;
  final String selectedTabId;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelectTab;
  final VoidCallback? onEndSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final checksAsync = ref.watch(barSessionChecksProvider(session.id));
    final sessionChecks = checksAsync.maybeWhen(
      data: (checks) => checks,
      orElse: () => const <BarSessionCheckSummary>[],
    );
    final availableTabs = _availableTabsForSession(session, sessionChecks);
    final effectiveSelectedTabId =
        availableTabs.any((tab) => tab.id == selectedTabId)
        ? selectedTabId
        : availableTabs.isNotEmpty
        ? availableTabs.first.id
        : '';
    final transactionTotal = effectiveSelectedTabId.isEmpty
        ? 0
        : session.transactionTotalByGroup(effectiveSelectedTabId);
    final filteredTransactions = session.transactions
        .where(
          (transaction) =>
              effectiveSelectedTabId.isNotEmpty &&
              transaction.matchesGroup(effectiveSelectedTabId),
        )
        .toList(growable: false);
    final isLive = _isLiveSession(session);
    final sessionTone = isLive ? _SessionTone.info : _SessionTone.subtle;
    final pendingBarTotal = _heldSessionCheckTotal(sessionChecks);
    final usesHeldAmount =
        pendingBarTotal > 0 && session.resolvedTotalAmount <= 0;
    final staffLabel = _resolvedSessionStaffLabel(session);
    final detailChips = <Widget>[
      if (session.displayLocker != '-')
        _InfoChip(icon: Icons.key_outlined, label: session.displayLocker),
      _InfoChip(
        icon: Icons.login_rounded,
        label: 'In ${_formatTime(session.startedAt)}',
      ),
      if (session.endedAt != null)
        _InfoChip(
          icon: Icons.logout_rounded,
          label: 'Out ${_formatTime(session.endedAt)}',
          tone: _SessionTone.subtle,
        ),
      _InfoChip(
        icon: Icons.timelapse_rounded,
        label: _formatDuration(session.startedAt, session.endedAt),
      ),
      if (staffLabel != null)
        _InfoChip(icon: Icons.badge_outlined, label: staffLabel),
      if (session.paid != null)
        _InfoChip(
          icon: session.isPaid
              ? Icons.task_alt_rounded
              : Icons.pending_actions_rounded,
          label: session.isPaid ? 'Paid' : 'Unpaid',
          tone: session.isPaid ? _SessionTone.success : _SessionTone.warning,
        ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: _sessionCardDecoration(
        tone: sessionTone,
        emphasized: expanded,
      ),
      child: Column(
        children: [
          AppClientListItem(
            leading: AppClientPresenceAvatar(
              label: clientName,
              fallback: '${index + 1}',
              imageUrl: clientImageUrl,
              isOnline: isLive,
            ),
            title: clientName,
            titleMaxLines: 2,
            titleStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.04,
            ),
            subtitle: clientMeta != null && clientMeta!.trim().isNotEmpty
                ? Text(
                    clientMeta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _sessionAlpha(AppColors.secondary, 0.86),
                    ),
                  )
                : null,
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 104),
              child: Align(
                alignment: Alignment.topRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _SessionMetricPill(
                    value: _formatMoney(
                      usesHeldAmount
                          ? pendingBarTotal
                          : session.resolvedTotalAmount,
                      withUnit: true,
                    ),
                    tone: usesHeldAmount
                        ? _SessionTone.warning
                        : _SessionTone.success,
                  ),
                ),
              ),
            ),
            footer: detailChips.isEmpty
                ? null
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _withSpacing(detailChips)),
                  ),
            onTap: onToggle,
            padding: const EdgeInsets.all(14),
            borderRadius: const BorderRadius.all(Radius.circular(24)),
          ),
          if (expanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: _sessionAlpha(AppColors.border, 0.42),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DetailValueTile(
                        label: 'Check in',
                        value: _formatTime(session.startedAt),
                        detail: _formatCompactDate(session.startedAt),
                      ),
                      _DetailValueTile(
                        label: 'Check out',
                        value: _formatTime(session.endedAt),
                        detail: session.endedAt == null
                            ? 'Live'
                            : _formatCompactDate(session.endedAt),
                      ),
                      _DetailValueTile(
                        label: 'Duration',
                        value: _formatDuration(
                          session.startedAt,
                          session.endedAt,
                        ),
                        detail: session.paid == null
                            ? null
                            : (session.isPaid ? 'Paid' : 'Unpaid'),
                      ),
                    ],
                  ),
                  if (onEndSession != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.tonalIcon(
                        onPressed: isEnding ? null : onEndSession,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          backgroundColor: _sessionAlpha(
                            const Color(0xFFE48764),
                            0.16,
                          ),
                          foregroundColor: const Color(0xFFE48764),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: isEnding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.stop_circle_outlined),
                        label: Text(isEnding ? 'Ending...' : 'End session'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (availableTabs.isNotEmpty) ...[
                    _SessionTransactionTabs(
                      tabs: availableTabs,
                      selectedTabId: effectiveSelectedTabId,
                      onSelected: onSelectTab,
                    ),
                    const SizedBox(height: 12),
                    _SessionTransactionPanel(
                      session: session,
                      selectedTab: availableTabs.firstWhere(
                        (tab) => tab.id == effectiveSelectedTabId,
                        orElse: () => availableTabs.first,
                      ),
                      filteredTransactions: filteredTransactions,
                      transactionTotal: transactionTotal,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailValueTile extends StatelessWidget {
  const _DetailValueTile({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 108, maxWidth: 160),
      padding: const EdgeInsets.all(14),
      decoration: _sessionPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _sessionAlpha(AppColors.secondary, 0.82),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionTransactionTabs extends StatelessWidget {
  const _SessionTransactionTabs({
    required this.tabs,
    required this.selectedTabId,
    required this.onSelected,
  });

  final List<_SessionTabDefinition> tabs;
  final String selectedTabId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          for (var index = 0; index < tabs.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: _SessionTogglePill(
                label: tabs[index].label,
                icon: tabs[index].icon,
                selected: selectedTabId == tabs[index].id,
                onTap: () => onSelected(tabs[index].id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SessionTransactionPanel extends StatelessWidget {
  const _SessionTransactionPanel({
    required this.session,
    required this.selectedTab,
    required this.filteredTransactions,
    required this.transactionTotal,
  });

  final GymSessionSummary session;
  final _SessionTabDefinition selectedTab;
  final List<GymSessionTransactionSummary> filteredTransactions;
  final num transactionTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: _sessionPanelDecoration(
        tone: _toneForSessionTab(selectedTab.id),
        outlined: true,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _SessionInlineBadge(
                          icon: selectedTab.icon,
                          label: selectedTab.label,
                          tone: _toneForSessionTab(selectedTab.id),
                        ),
                        const SizedBox(width: 6),
                        _SessionInlineBadge(
                          icon: Icons.receipt_long_rounded,
                          label: '${filteredTransactions.length} items',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _SessionMetricPill(
                    value: _formatMoney(transactionTotal, withUnit: true),
                    tone: _SessionTone.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (filteredTransactions.isEmpty)
              Text(
                session.transactions.isEmpty
                    ? 'No embedded transactions were found for this session yet.'
                    : 'No ${selectedTab.label.toLowerCase()} transactions in this session.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _sessionAlpha(AppColors.secondary, 0.84),
                ),
              )
            else
              Column(
                children: [
                  for (
                    var index = 0;
                    index < filteredTransactions.length;
                    index++
                  ) ...[
                    if (index > 0) const SizedBox(height: 10),
                    _SessionTransactionRow(
                      transaction: filteredTransactions[index],
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionTransactionRow extends StatelessWidget {
  const _SessionTransactionRow({required this.transaction});

  final GymSessionTransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _transactionMeta(transaction);
    final tags = <Widget>[
      if (transaction.paymentMethod != null &&
          transaction.paymentMethod!.trim().isNotEmpty)
        _SessionInlineBadge(
          icon: _sessionPaymentMethodIcon(transaction.paymentMethod),
          label: _sessionPaymentMethodLabel(transaction.paymentMethod),
          tone: _sessionPaymentMethodTone(transaction.paymentMethod),
        ),
      if (transaction.createdAt != null)
        _SessionInlineBadge(
          icon: Icons.schedule_rounded,
          label: _formatTime(transaction.createdAt),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _sessionAlpha(AppColors.panel, 0.98),
            _sessionAlpha(AppColors.panelRaised, 0.96),
          ],
        ),
        border: Border.all(color: _sessionAlpha(AppColors.border, 0.72)),
        boxShadow: [
          BoxShadow(
            color: _sessionAlpha(AppColors.ink, 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  transaction.displayTitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: _SessionMetricPill(
                  value: _formatMoney(transaction.amount ?? 0, withUnit: true),
                  tone: _SessionTone.success,
                ),
              ),
            ],
          ),
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _withSpacing(tags, spacing: 6)),
            ),
          ] else if (meta != 'Session transaction') ...[
            const SizedBox(height: 6),
            Text(
              meta,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _sessionAlpha(AppColors.secondary, 0.82),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    this.tone = _SessionTone.defaultTone,
  });

  final IconData icon;
  final String label;
  final _SessionTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _sessionToneColors(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _sessionAlpha(colors.background, 0.92),
            _sessionAlpha(colors.background, 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _sessionAlpha(colors.border, 0.84)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.foreground),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.foreground,
              fontSize: 11.2,
            ),
          ),
        ],
      ),
    );
  }
}

enum _SessionViewFilter { online, completed, all }

enum _SessionTone { defaultTone, info, success, warning, danger, subtle }

class _SessionToneColors {
  const _SessionToneColors({
    required this.background,
    required this.border,
    required this.foreground,
  });

  final Color background;
  final Color border;
  final Color foreground;
}

_SessionToneColors _sessionToneColors(_SessionTone tone) {
  switch (tone) {
    case _SessionTone.info:
      return const _SessionToneColors(
        background: Color(0xFFEAF4FF),
        border: Color(0xFF9CCBFF),
        foreground: Color(0xFF2563EB),
      );
    case _SessionTone.success:
      return const _SessionToneColors(
        background: Color(0xFFEAF8F0),
        border: Color(0xFF99D7B0),
        foreground: Color(0xFF1F8A57),
      );
    case _SessionTone.warning:
      return const _SessionToneColors(
        background: Color(0xFFFFF6E6),
        border: Color(0xFFF1CA7A),
        foreground: Color(0xFFB7791F),
      );
    case _SessionTone.danger:
      return const _SessionToneColors(
        background: Color(0xFFFFEEE8),
        border: Color(0xFFF0AA90),
        foreground: Color(0xFFD46A4A),
      );
    case _SessionTone.subtle:
      return const _SessionToneColors(
        background: Color(0xFFF1F5FA),
        border: Color(0xFFD5E0EB),
        foreground: Color(0xFF5F748C),
      );
    case _SessionTone.defaultTone:
      return const _SessionToneColors(
        background: Color(0xFFFFFFFF),
        border: Color(0xFFD6E1EC),
        foreground: Color(0xFF16324F),
      );
  }
}

BoxDecoration _sessionPanelDecoration({
  _SessionTone tone = _SessionTone.defaultTone,
  bool outlined = false,
}) {
  final colors = _sessionToneColors(tone);

  return BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _sessionAlpha(AppColors.panel, 0.98),
        _sessionAlpha(colors.background, 0.98),
      ],
    ),
    border: Border.all(
      color: _sessionAlpha(
        outlined ? colors.border : AppColors.border,
        outlined ? 0.86 : 0.72,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: _sessionAlpha(AppColors.ink, 0.06),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

BoxDecoration _sessionCardDecoration({
  _SessionTone tone = _SessionTone.defaultTone,
  bool emphasized = false,
}) {
  final colors = _sessionToneColors(tone);

  return BoxDecoration(
    borderRadius: BorderRadius.circular(24),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: emphasized
          ? [
              _sessionAlpha(AppColors.panel, 0.99),
              _sessionAlpha(colors.background, 0.98),
            ]
          : const [AppColors.panel, AppColors.panelRaised],
    ),
    border: Border.all(
      color: _sessionAlpha(
        emphasized ? colors.border : AppColors.border,
        emphasized ? 0.9 : 0.84,
      ),
    ),
    boxShadow: [
      BoxShadow(
        color: _sessionAlpha(AppColors.ink, 0.08),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

class _SessionMetricPill extends StatelessWidget {
  const _SessionMetricPill({
    required this.value,
    this.tone = _SessionTone.defaultTone,
  });

  final String value;
  final _SessionTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _sessionToneColors(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _sessionAlpha(colors.background, 0.98),
            _sessionAlpha(colors.background, 0.9),
          ],
        ),
        border: Border.all(color: _sessionAlpha(colors.border, 0.88)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colors.foreground,
              fontSize: 10.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTogglePill extends StatelessWidget {
  const _SessionTogglePill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEAF5FF), Color(0xFFDCEEFF)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.panel, AppColors.panelRaised],
                  ),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : _sessionAlpha(AppColors.border, 0.7),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? AppColors.primary : AppColors.ink,
                    fontSize: 10.2,
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

class _SessionControlButton extends StatelessWidget {
  const _SessionControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.expanded = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final button = AppGlassControlButton(
      leadingIcon: icon,
      label: label,
      onTap: onTap,
    );

    if (expanded) {
      return SizedBox(width: double.infinity, child: button);
    }

    return button;
  }
}

class _SessionInlineBadge extends StatelessWidget {
  const _SessionInlineBadge({
    required this.icon,
    required this.label,
    this.tone = _SessionTone.subtle,
  });

  final IconData icon;
  final String label;
  final _SessionTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _sessionToneColors(tone);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _sessionAlpha(colors.background, 0.92),
            _sessionAlpha(colors.background, 0.74),
          ],
        ),
        border: Border.all(color: _sessionAlpha(colors.border, 0.84)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

List<Widget> _withSpacing(List<Widget> children, {double spacing = 8}) {
  if (children.isEmpty) {
    return const <Widget>[];
  }

  final spaced = <Widget>[];
  for (var index = 0; index < children.length; index++) {
    if (index > 0) {
      spaced.add(SizedBox(width: spacing));
    }
    spaced.add(children[index]);
  }
  return spaced;
}

String _formatCompactDate(DateTime? value) {
  if (value == null) {
    return '-';
  }

  final local = value.toLocal();
  return _isToday(local)
      ? 'Today'
      : '${local.day.toString().padLeft(2, '0')} ${_monthName(local.month)}';
}

_SessionTone _toneForSessionTab(String tabId) {
  switch (tabId.trim().toLowerCase()) {
    case 'bar':
      return _SessionTone.info;
    case 'package':
      return _SessionTone.warning;
    case 'trainer':
      return _SessionTone.danger;
    default:
      return _SessionTone.subtle;
  }
}

String _sessionPaymentMethodLabel(String? value) {
  final normalized = value?.trim().toLowerCase();
  switch (normalized) {
    case 'cash':
      return 'Cash';
    case 'card':
      return 'Card';
    case 'click':
      return 'Click';
    case 'payme':
      return 'Payme';
    case 'transfer':
      return 'Transfer';
    case 'debt':
      return 'Debt';
    default:
      return value == null || value.trim().isEmpty
          ? 'Method'
          : _titleCase(value);
  }
}

IconData _sessionPaymentMethodIcon(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'cash':
      return Icons.payments_rounded;
    case 'card':
      return Icons.credit_card_rounded;
    case 'click':
      return Icons.touch_app_rounded;
    case 'payme':
      return Icons.phone_android_rounded;
    case 'transfer':
      return Icons.swap_horiz_rounded;
    case 'debt':
      return Icons.warning_amber_rounded;
    default:
      return Icons.account_balance_wallet_rounded;
  }
}

_SessionTone _sessionPaymentMethodTone(String? value) {
  switch (value?.trim().toLowerCase()) {
    case 'cash':
      return _SessionTone.warning;
    case 'card':
      return _SessionTone.info;
    case 'click':
      return _SessionTone.success;
    case 'payme':
      return _SessionTone.danger;
    case 'transfer':
      return _SessionTone.subtle;
    case 'debt':
      return _SessionTone.warning;
    default:
      return _SessionTone.defaultTone;
  }
}

class _SessionAnalytics {
  const _SessionAnalytics({
    required this.totalCount,
    required this.onlineCount,
    required this.closedCount,
    required this.totalRevenue,
    required this.barRevenue,
    required this.packageRevenue,
    required this.trainerRevenue,
  });

  factory _SessionAnalytics.fromSessions(List<GymSessionSummary> sessions) {
    num totalRevenue = 0;
    num barRevenue = 0;
    num packageRevenue = 0;
    num trainerRevenue = 0;

    for (final session in sessions) {
      totalRevenue += session.resolvedTotalAmount;
      barRevenue += session.transactionTotalByGroup('bar');
      packageRevenue += session.transactionTotalByGroup('package');
      trainerRevenue += session.transactionTotalByGroup('trainer');
    }

    return _SessionAnalytics(
      totalCount: sessions.length,
      onlineCount: sessions.where(_isLiveSession).length,
      closedCount: sessions
          .where((session) => session.isClosed || !_isLiveSession(session))
          .length,
      totalRevenue: totalRevenue,
      barRevenue: barRevenue,
      packageRevenue: packageRevenue,
      trainerRevenue: trainerRevenue,
    );
  }

  final int totalCount;
  final int onlineCount;
  final int closedCount;
  final num totalRevenue;
  final num barRevenue;
  final num packageRevenue;
  final num trainerRevenue;
}

class _SessionTabDefinition {
  const _SessionTabDefinition({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

const _sessionTabs = <_SessionTabDefinition>[
  _SessionTabDefinition(
    id: 'bar',
    label: 'Bar',
    icon: Icons.local_cafe_outlined,
  ),
  _SessionTabDefinition(
    id: 'package',
    label: 'Package',
    icon: Icons.inventory_2_outlined,
  ),
  _SessionTabDefinition(
    id: 'trainer',
    label: 'Trainer',
    icon: Icons.fitness_center_outlined,
  ),
];

List<_SessionTabDefinition> _availableTabsForSession(
  GymSessionSummary session, [
  List<BarSessionCheckSummary> checks = const <BarSessionCheckSummary>[],
]) {
  return _sessionTabs
      .where((tab) {
        if (tab.id == 'bar' && _heldSessionCheckTotal(checks) > 0) {
          return true;
        }

        return session.transactions.any(
          (transaction) => transaction.matchesGroup(tab.id),
        );
      })
      .toList(growable: false);
}

String _defaultTabForSession(
  GymSessionSummary session, [
  List<BarSessionCheckSummary> checks = const <BarSessionCheckSummary>[],
]) {
  final availableTabs = _availableTabsForSession(session, checks);
  if (availableTabs.isNotEmpty) {
    return availableTabs.first.id;
  }

  return _sessionTabs.first.id;
}

bool _matchesSessionViewFilter(
  GymSessionSummary session,
  _SessionViewFilter filter,
) {
  switch (filter) {
    case _SessionViewFilter.online:
      return _isLiveSession(session);
    case _SessionViewFilter.completed:
      return session.isClosed || !_isLiveSession(session);
    case _SessionViewFilter.all:
      return true;
  }
}

String _resolvedSessionClientName(
  GymSessionSummary session,
  Map<String, GymClientSummary> clientsById,
) {
  final client = session.clientId == null
      ? null
      : clientsById[session.clientId!.trim()];

  if (client != null && client.fullName.trim().isNotEmpty) {
    return client.fullName;
  }

  if (session.clientName?.trim().isNotEmpty == true) {
    return session.clientName!.trim();
  }

  return 'Session';
}

String? _resolvedSessionClientMeta(
  GymSessionSummary session,
  Map<String, GymClientSummary> clientsById,
) {
  final client = session.clientId == null
      ? null
      : clientsById[session.clientId!.trim()];
  final parts = <String>[];

  if (client?.phone?.trim().isNotEmpty == true) {
    parts.add(client!.phone!.trim());
  }
  if (session.packageName?.trim().isNotEmpty == true) {
    parts.add(session.packageName!.trim());
  }

  if (parts.isNotEmpty) {
    return parts.join(' • ');
  }

  return null;
}

String? _resolvedSessionClientImageUrl(
  GymSessionSummary session,
  Map<String, GymClientSummary> clientsById,
) {
  final client = session.clientId == null
      ? null
      : clientsById[session.clientId!.trim()];
  final value = client?.imageUrl?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  return value;
}

String? _resolvedSessionStaffLabel(GymSessionSummary session) {
  final normalized = session.staffName?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (_looksLikeOpaqueSessionId(normalized)) {
    return null;
  }

  return normalized;
}

String _transactionMeta(GymSessionTransactionSummary transaction) {
  final parts = <String>[];

  if (transaction.paymentMethod != null) {
    parts.add(_titleCase(transaction.paymentMethod!));
  }
  if (transaction.createdAt != null) {
    parts.add(_formatTime(transaction.createdAt));
  }

  if (parts.isEmpty) {
    return 'Session transaction';
  }

  return parts.join(' • ');
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
  final normalized = difference.isNegative ? Duration.zero : difference;
  final days = normalized.inDays;
  final hours = normalized.inHours.remainder(24);
  final minutes = normalized.inMinutes.remainder(60);

  final parts = <String>[];
  if (days > 0) {
    parts.add('$days d');
  }
  if (hours > 0) {
    parts.add('$hours h');
  }
  if (minutes > 0 || parts.isEmpty) {
    parts.add('$minutes min');
  }

  return parts.join(' ');
}

bool _matchesSelectedDateFilter(
  GymSessionSummary session,
  AppDateRangeFilter filter,
) {
  final today = DateUtils.dateOnly(DateTime.now());

  if (_isLiveSession(session) && appDateRangeIncludesDate(filter, today)) {
    return true;
  }

  final sessionDates = <DateTime?>[
    session.startedAt,
    session.createdAt,
    session.endedAt,
  ];

  for (final value in sessionDates) {
    if (value == null) {
      continue;
    }

    if (appDateRangeIncludesDate(filter, value)) {
      return true;
    }
  }

  return false;
}

int _compareSessions(GymSessionSummary first, GymSessionSummary second) {
  final firstLive = _isLiveSession(first);
  final secondLive = _isLiveSession(second);

  if (firstLive != secondLive) {
    return firstLive ? -1 : 1;
  }

  final firstDate = _sortDate(first);
  final secondDate = _sortDate(second);
  return secondDate.compareTo(firstDate);
}

DateTime _sortDate(GymSessionSummary session) {
  return (session.startedAt ??
          session.createdAt ??
          session.endedAt ??
          DateTime.fromMillisecondsSinceEpoch(0))
      .toLocal();
}

bool _isLiveSession(GymSessionSummary session) {
  return session.isOnline || session.isActive;
}

bool _isToday(DateTime value) {
  return DateUtils.isSameDay(
    DateUtils.dateOnly(value),
    DateUtils.dateOnly(DateTime.now()),
  );
}

String _monthName(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return months[month - 1];
}

String _formatMoney(num value, {bool withUnit = false}) {
  return formatAppMoney(value, withUnit: withUnit);
}

String _titleCase(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return value;
  }

  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}

String _normalizeErrorMessage(Object error) {
  final message = error.toString();
  const prefix = 'Exception: ';
  if (message.startsWith(prefix)) {
    return message.substring(prefix.length);
  }

  return message;
}

num _heldSessionCheckTotal(Iterable<BarSessionCheckSummary> checks) {
  return checks.fold<num>(0, (sum, check) {
    if (!check.isHeld) {
      return sum;
    }

    return sum + (check.totalAmount ?? 0);
  });
}

bool _looksLikeOpaqueSessionId(String value) {
  final normalized = value.trim();
  if (normalized.length < 10) {
    return false;
  }
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(normalized)) {
    return false;
  }

  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(normalized);
  final hasDigit = RegExp(r'\d').hasMatch(normalized);
  return hasLetter && hasDigit;
}

Color _sessionAlpha(Color color, double opacity) =>
    color.withValues(alpha: opacity);
