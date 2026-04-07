import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'app_backdrop.dart';

enum AppShellDestination { profile, clients, sessions, finance, packages }

class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({
    super.key,
    required this.navigationShell,
    required this.barMenuPath,
    required this.statsPath,
  });

  final StatefulNavigationShell navigationShell;
  final String barMenuPath;
  final String statsPath;

  AppShellDestination get _currentDestination =>
      AppShellDestination.values[navigationShell.currentIndex];

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDestination = _currentDestination;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bodyBottomPadding = keyboardVisible ? 24.0 : 116.0;

    return SizedBox.expand(
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('AllClubs Mobile'),
          actions: [
            _HeaderAction(
              icon: Icons.point_of_sale_rounded,
              label: 'POS',
              onTap: () => context.go(barMenuPath),
            ),
            const SizedBox(width: 8),
            _HeaderAction(
              icon: Icons.stacked_bar_chart_rounded,
              label: 'Stats',
              onTap: () => context.go(statsPath),
            ),
            const SizedBox(width: 8),
            _HeaderAction(
              icon: Icons.account_circle_rounded,
              label: 'Profile',
              selected: currentDestination == AppShellDestination.profile,
              onTap: () => _goBranch(0),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SizedBox.expand(
          child: AppBackdrop(
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(bottom: bodyBottomPadding),
                child: SizedBox.expand(child: navigationShell),
              ),
            ),
          ),
        ),
        bottomNavigationBar: keyboardVisible
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF152538), Color(0xFF0C1727)],
                          ),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 30,
                              offset: Offset(0, 14),
                            ),
                            BoxShadow(
                              color: Color(0x2D2AD4C8),
                              blurRadius: 18,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _BottomItem(
                                icon: Icons.groups_2_outlined,
                                selectedIcon: Icons.groups_2_rounded,
                                label: 'Clients',
                                selected:
                                    currentDestination ==
                                    AppShellDestination.clients,
                                onTap: () => _goBranch(1),
                              ),
                            ),
                            Expanded(
                              child: _BottomItem(
                                icon: Icons.av_timer_outlined,
                                selectedIcon: Icons.av_timer_rounded,
                                label: 'Sessions',
                                selected:
                                    currentDestination ==
                                    AppShellDestination.sessions,
                                onTap: () => _goBranch(2),
                              ),
                            ),
                            Expanded(
                              child: _BottomItem(
                                icon:
                                    Icons.account_balance_wallet_outlined,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF18424B), Color(0xFF112E3E)],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF162436), Color(0xFF101B2B)],
                  ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x332AD4C8),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: selected ? colorScheme.primary : colorScheme.onSurface,
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
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0x1F2AD4C8) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? const Color(0x3D2AD4C8) : Colors.transparent,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 18,
                  height: 3,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: selected ? colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF163941)
                          : const Color(0xFF122033),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      selected ? selectedIcon : icon,
                      size: 17,
                      color: selected
                          ? colorScheme.primary
                          : AppColors.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected ? AppColors.ink : AppColors.mutedInk,
                      fontWeight: FontWeight.w600,
                      fontSize: 8.8,
                      letterSpacing: 0.1,
                      height: 1.05,
                    ),
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
