import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/bootstrap/application/bootstrap_controller.dart';
import '../localization/app_language.dart';
import '../routing/app_router.dart';
import '../theme/app_theme.dart';
import 'app_backdrop.dart';
import 'app_person_avatar.dart';
import 'liquid_glass.dart';

enum AppShellDestination { profile, clients, sessions, finance, packages }

class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
    required this.barMenuPath,
    required this.statsPath,
  });

  final StatefulNavigationShell navigationShell;
  final String barMenuPath;
  final String statsPath;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  DateTime? _lastBackAt;
  String? _lastLocation;

  AppShellDestination get _currentDestination =>
      AppShellDestination.values[widget.navigationShell.currentIndex];

  void _goBranch(int index) {
    _lastBackAt = null;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  void _openProfilePage() {
    _lastBackAt = null;
    context.go(AppRoutes.profile);
  }

  _ProfileSectionHeader? _resolveProfileSectionHeader(Uri currentUri) {
    if (currentUri.path != AppRoutes.profile) {
      return null;
    }

    return switch (currentUri.queryParameters['section']) {
      'settings' => const _ProfileSectionHeader(title: 'Settings'),
      'staff' => const _ProfileSectionHeader(title: 'Staffs'),
      'subscription' => const _ProfileSectionHeader(title: 'Subscription'),
      'about' => const _ProfileSectionHeader(title: 'Biz haqimizda'),
      _ => null,
    };
  }

  Future<void> _handleBackPress() async {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      _lastBackAt = null;
      router.pop();
      return;
    }

    final currentUri = Uri.tryParse(_lastLocation ?? '');
    if (currentUri?.path == AppRoutes.profile) {
      final section = currentUri?.queryParameters['section'];
      if (section != null && section.isNotEmpty) {
        _lastBackAt = null;
        context.go(AppRoutes.profile);
        return;
      }
    }

    final now = DateTime.now();
    if (_lastBackAt == null ||
        now.difference(_lastBackAt!) > const Duration(seconds: 2)) {
      _lastBackAt = now;
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppStrings.of(ref).backAgainToExit)),
        );
      return;
    }

    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentDestination = _currentDestination;
    final currentUri = GoRouterState.of(context).uri;
    final profileHeader = _resolveProfileSectionHeader(currentUri);
    final currentLocation = currentUri.toString();
    if (_lastLocation != currentLocation) {
      _lastLocation = currentLocation;
      _lastBackAt = null;
    }
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final showBottomDock = !keyboardVisible;
    final bodyBottomPadding = keyboardVisible
        ? 24.0
        : showBottomDock
        ? 96.0
        : 18.0;
    final strings = AppStrings.of(ref);
    final session = ref.watch(bootstrapControllerProvider).session;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBackPress();
      },
      child: SizedBox.expand(
        child: Scaffold(
          extendBody: true,
          appBar: AppBar(
            toolbarHeight: 64,
            titleSpacing: profileHeader == null ? 14 : 8,
            title: profileHeader == null
                ? _ShellTitle(
                    gymName: session?.gym?.name,
                    gymLogoUrl: session?.gym?.logoUrl,
                  )
                : _ProfileSectionTitle(
                    title: profileHeader.title,
                    onBack: _openProfilePage,
                  ),
            actions: [
              _HeaderAction(
                icon: Icons.point_of_sale_rounded,
                label: strings.pos,
                onTap: () => context.go(widget.barMenuPath),
              ),
              const SizedBox(width: 6),
              _HeaderAction(
                icon: Icons.stacked_bar_chart_rounded,
                label: strings.stats,
                onTap: () => context.go(widget.statsPath),
              ),
              const SizedBox(width: 6),
              _HeaderAction(
                icon: Icons.account_circle_rounded,
                label: strings.profile,
                selected: currentDestination == AppShellDestination.profile,
                onTap: _openProfilePage,
              ),
              const SizedBox(width: 10),
            ],
          ),
          body: SizedBox.expand(
            child: AppBackdrop(
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(bottom: bodyBottomPadding),
                  child: SizedBox.expand(child: widget.navigationShell),
                ),
              ),
            ),
          ),
          bottomNavigationBar: showBottomDock
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: AppShadows.floating,
                          ),
                          child: AppLiquidGlass(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFFFFF), Color(0xFFF3F7FD)],
                            ),
                            child: SizedBox(
                              height: 56,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _BottomItem(
                                    icon: Icons.people_alt_outlined,
                                    selectedIcon: Icons.people_alt_rounded,
                                    label: strings.clients,
                                    selected:
                                        currentDestination ==
                                        AppShellDestination.clients,
                                    onTap: () => _goBranch(1),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomItem(
                                    icon: Icons.play_circle_outline_rounded,
                                    selectedIcon: Icons.play_circle_rounded,
                                    label: strings.sessions,
                                    selected:
                                        currentDestination ==
                                        AppShellDestination.sessions,
                                    onTap: () => _goBranch(2),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomItem(
                                    icon: Icons.payments_outlined,
                                    selectedIcon: Icons.payments_rounded,
                                    label: strings.finance,
                                    selected:
                                        currentDestination ==
                                        AppShellDestination.finance,
                                    onTap: () => _goBranch(3),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomItem(
                                    icon: Icons.widgets_outlined,
                                    selectedIcon: Icons.widgets_rounded,
                                    label: strings.packages,
                                    selected:
                                        currentDestination ==
                                        AppShellDestination.packages,
                                    onTap: () => _goBranch(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              : null,
        ),
      ),
    );
  }
}

class _ShellTitle extends StatelessWidget {
  const _ShellTitle({this.gymName, this.gymLogoUrl});

  final String? gymName;
  final String? gymLogoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedGymName = gymName != null && gymName!.trim().isNotEmpty
        ? gymName!.trim()
        : 'Gym';

    return Row(
      children: [
        AppPersonAvatar(
          label: resolvedGymName,
          fallback: 'GY',
          imageUrl: gymLogoUrl,
          size: 56,
          backgroundColor: AppColors.panelRaised,
          borderColor: AppColors.primary.withValues(alpha: 0.24),
          foregroundColor: AppColors.primary,
          useSolidBackground: true,
          showBorder: false,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            resolvedGymName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: AppLiquidGlass(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(14),
        gradient: selected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.14),
                  AppColors.accent.withValues(alpha: 0.08),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FB)],
              ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(
                icon,
                size: 18,
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionHeader {
  const _ProfileSectionHeader({required this.title});

  final String title;
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        AppLiquidGlass(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FB)],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(14),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomItem extends StatefulWidget {
  const _BottomItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_BottomItem> createState() => _BottomItemState();
}

class _BottomItemState extends State<_BottomItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = widget.selected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: _setPressed,
          onTapCancel: () => _setPressed(false),
          borderRadius: BorderRadius.circular(22),
          splashColor: AppColors.primary.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: _pressed ? 0.95 : 1.0,
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: selected ? AppGradients.primary : null,
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? widget.selectedIcon : widget.icon,
                    size: 20,
                    color: selected ? Colors.white : AppColors.mutedInk,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 11.8,
                      color: selected ? Colors.white : AppColors.mutedInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppShellBody extends StatelessWidget {
  const AppShellBody({
    super.key,
    required this.child,
    this.maxWidth = 560,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
    this.expandHeight = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool expandHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: expandHeight ? constraints.maxHeight : null,
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );
  }
}
