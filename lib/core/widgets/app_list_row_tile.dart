import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Canonical list row used across clients / sessions / packages / finance.
///
/// Standard layout:
///   [leading] [title + subtitle] [trailing]    <- top row, 56h
///   [meta strip of chips]                      <- optional bottom row, 28h
///
/// Sizes and paddings are fixed so rows look uniform across modules. Use this
/// instead of ad-hoc Container/Padding wrappers when rendering a list item.
class AppListRowTile extends StatelessWidget {
  const AppListRowTile({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.meta,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(4, 12, 4, 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.highlighted = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Right-aligned widget (typically a single [AppDataChip] or icon).
  final Widget? trailing;

  /// Optional bottom row with up to 4 chips. Pre-spaced 8px apart.
  final List<Widget>? meta;

  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: AppColors.primary.withValues(alpha: 0.06),
        highlightColor: AppColors.primary.withValues(alpha: 0.04),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: highlighted
                ? AppColors.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: borderRadius,
          ),
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
              if (meta != null && meta!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 60),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: meta!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
