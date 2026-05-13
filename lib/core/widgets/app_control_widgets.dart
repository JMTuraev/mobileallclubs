import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'liquid_glass.dart';

class AppGlassControlButton extends StatelessWidget {
  const AppGlassControlButton({
    super.key,
    required this.leadingIcon,
    required this.label,
    this.onTap,
    this.trailingIcon,
    this.trailing,
    this.height = _appControlHeight,
    this.borderRadius = _appControlBorderRadius,
  });

  final IconData leadingIcon;
  final String label;
  final VoidCallback? onTap;
  final IconData? trailingIcon;
  final Widget? trailing;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: AppLiquidGlass(
        padding: EdgeInsets.zero,
        borderRadius: borderRadius,
        gradient: _defaultControlGradient,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isBounded = constraints.hasBoundedWidth;
                final labelText = Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge,
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisSize: isBounded
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    children: [
                      const SizedBox(width: 2),
                      Icon(leadingIcon, color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      if (isBounded) Expanded(child: labelText) else labelText,
                      if (trailing != null) ...[trailing!],
                      if (trailing == null && trailingIcon != null)
                        _AppControlTrailingIcon(icon: trailingIcon!),
                    ],
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

class AppGlassIconButton extends StatelessWidget {
  const AppGlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = _appControlHeight,
    this.iconColor = AppColors.primary,
    this.gradient = _defaultControlGradient,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color iconColor;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: AppLiquidGlass(
        padding: EdgeInsets.zero,
        borderRadius: _appControlBorderRadius,
        gradient: gradient,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: _appControlBorderRadius,
            child: Center(child: Icon(icon, color: iconColor, size: 20)),
          ),
        ),
      ),
    );
  }
}

class AppGlassSearchField extends StatelessWidget {
  const AppGlassSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.clearVisible,
    this.hintText = 'Search',
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.height = _appControlHeight,
    this.borderRadius = _appControlBorderRadius,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool clearVisible;
  final String hintText;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: height,
      child: AppLiquidGlass(
        padding: EdgeInsets.zero,
        borderRadius: borderRadius,
        gradient: _defaultControlGradient,
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    keyboardType: keyboardType,
                    inputFormatters: inputFormatters,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: hintText,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: _alpha(AppColors.mutedInk, 0.92),
                      ),
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: clearVisible
                      ? IconButton(
                          key: const ValueKey('clear-search'),
                          onPressed: onClear,
                          icon: const Icon(Icons.close_rounded, size: 17),
                          color: AppColors.mutedInk,
                          splashRadius: 16,
                        )
                      : const SizedBox(width: 18, height: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppCalendarControlButton extends StatelessWidget {
  const AppCalendarControlButton({
    super.key,
    required this.label,
    required this.onTap,
    this.trailingIcon = Icons.edit_calendar_rounded,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return AppGlassControlButton(
      leadingIcon: Icons.calendar_today_rounded,
      label: label,
      onTap: onTap,
      trailingIcon: trailingIcon,
    );
  }
}

class AppControlsHeaderSurface extends StatelessWidget {
  const AppControlsHeaderSurface({
    super.key,
    required this.child,
    this.overlapsContent = false,
    this.padding = const EdgeInsets.only(top: 2, bottom: 2),
  });

  final Widget child;
  final bool overlapsContent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      color: _alpha(AppColors.canvas, overlapsContent ? 0.98 : 0.94),
      padding: padding,
      child: child,
    );
  }
}

class AppControlsSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  const AppControlsSliverHeaderDelegate({
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
    return AppControlsHeaderSurface(
      overlapsContent: overlapsContent,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant AppControlsSliverHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.extent != extent;
  }
}

class AppControlTogglePill extends StatelessWidget {
  const AppControlTogglePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  final IconData? icon;

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.16),
                      AppColors.accent.withValues(alpha: 0.1),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FB)],
                  ),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.28)
                  : _alpha(AppColors.border, 0.7),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isBounded = constraints.hasBoundedWidth;
              final labelText = Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.canvasStrong : AppColors.ink,
                  fontSize: 10.9,
                ),
              );

              return Row(
                mainAxisSize: isBounded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 14,
                      color: selected ? AppColors.canvasStrong : AppColors.ink,
                    ),
                    const SizedBox(width: 5),
                  ],
                  if (isBounded) Flexible(child: labelText) else labelText,
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.panelRaised,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 10.0,
                          color: selected
                              ? AppColors.canvasStrong
                              : AppColors.mutedInk,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AppControlTrailingIcon extends StatelessWidget {
  const _AppControlTrailingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.panelRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _alpha(AppColors.border, 0.6)),
      ),
      child: Icon(icon, color: AppColors.ink, size: 18),
    );
  }
}

const LinearGradient _defaultControlGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FB)],
);

const double _appControlHeight = 50;
const BorderRadius _appControlBorderRadius = BorderRadius.all(
  Radius.circular(20),
);
const double appControlsHeaderExtent = 104;
const EdgeInsets appControlsPagePadding = EdgeInsets.fromLTRB(12, 2, 12, 8);

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);
