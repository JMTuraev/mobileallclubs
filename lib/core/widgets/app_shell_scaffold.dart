import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'app_backdrop.dart';
import 'liquid_glass.dart';

enum AppShellDestination { profile, clients, sessions, finance, packages }

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);

class AppShellScaffold extends StatefulWidget {
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
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold> {
  DateTime? _lastBackAt;

  AppShellDestination get _currentDestination =>
      AppShellDestination.values[widget.navigationShell.currentIndex];

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  Future<void> _handleBackPress() async {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
      return;
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
          const SnackBar(content: Text('Back again to exit the app.')),
        );
      return;
    }

    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final currentDestination = _currentDestination;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bodyBottomPadding = keyboardVisible ? 24.0 : 96.0;

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
            toolbarHeight: 72,
            titleSpacing: 18,
            title: _ShellTitle(title: _titleForDestination(currentDestination)),
            actions: [
              _HeaderAction(
                icon: Icons.point_of_sale_rounded,
                label: 'POS',
                onTap: () => context.go(widget.barMenuPath),
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                icon: Icons.stacked_bar_chart_rounded,
                label: 'Stats',
                onTap: () => context.go(widget.statsPath),
              ),
              const SizedBox(width: 8),
              _HeaderAction(
                icon: Icons.account_circle_rounded,
                label: 'Profile',
                selected: currentDestination == AppShellDestination.profile,
                onTap: () => _goBranch(0),
              ),
              const SizedBox(width: 14),
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
          bottomNavigationBar: keyboardVisible
              ? null
              : SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 560),
                        child: AppLiquidGlass(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 5,
                          ),
                          borderRadius: BorderRadius.circular(26),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xEE243142), Color(0xD2101720)],
                          ),
                          child: SizedBox(
                            height: 54,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _BottomItem(
                                    icon: Icons.people_alt_outlined,
                                    selectedIcon: Icons.people_alt_rounded,
                                    label: 'Clients',
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
                                    label: 'Sessions',
                                    selected:
                                        currentDestination ==
                                        AppShellDestination.sessions,
                                    onTap: () => _goBranch(2),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomItem(
                                    icon: Icons.account_balance_wallet_outlined,
                                    selectedIcon:
                                        Icons.account_balance_wallet_rounded,
                                    label: 'Finance',
                                    selected:
                                        currentDestination ==
                                        AppShellDestination.finance,
                                    onTap: () => _goBranch(3),
                                  ),
                                ),
                                Expanded(
                                  child: _BottomItem(
                                    icon: Icons.inventory_2_outlined,
                                    selectedIcon: Icons.inventory_2_rounded,
                                    label: 'Packages',
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
        ),
      ),
    );
  }
}

String _titleForDestination(AppShellDestination destination) {
  return switch (destination) {
    AppShellDestination.profile => 'Overview',
    AppShellDestination.clients => 'Clients',
    AppShellDestination.sessions => 'Sessions',
    AppShellDestination.finance => 'Finance',
    AppShellDestination.packages => 'Packages',
  };
}

class _ShellTitle extends StatelessWidget {
  const _ShellTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF8FBFF), Color(0xFFDCE5F0)],
            ),
            border: Border.all(color: _alpha(Colors.white, 0.18)),
          ),
          child: const Icon(
            Icons.forum_rounded,
            color: AppColors.canvasStrong,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('AllClubs', style: theme.textTheme.titleLarge),
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primary,
                letterSpacing: 0.2,
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(15),
        gradient: selected
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xCCF7FAFF), Color(0x7ADCE4EE)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xD22B394A), Color(0xC8151D27)],
              ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 20,
                color: selected ? AppColors.canvasStrong : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: selected
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCCF8FBFF), Color(0x80DDE5F0)],
                    )
                  : null,
              border: Border.all(
                color: selected ? const Color(0x88FFFFFF) : Colors.transparent,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 20,
                  color: selected
                      ? AppColors.canvasStrong
                      : _alpha(Colors.white, 0.95),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 11.8,
                    color: selected
                        ? AppColors.canvasStrong
                        : _alpha(Colors.white, 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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
