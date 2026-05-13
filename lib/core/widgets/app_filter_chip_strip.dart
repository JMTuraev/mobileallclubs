import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One canonical horizontal filter strip used in clients / sessions / finance.
///
/// Renders a Material-3 styled SegmentedControl-like row of pill chips. Each
/// chip has the same height (36) and the same active/inactive treatment. Adds
/// an optional count badge inside the chip (e.g. "All • 212").
class AppFilterChipStripItem {
  const AppFilterChipStripItem({
    required this.id,
    required this.label,
    this.count,
    this.icon,
  });

  final String id;
  final String label;
  final int? count;
  final IconData? icon;
}

class AppFilterChipStrip extends StatelessWidget {
  const AppFilterChipStrip({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.scrollable = false,
  });

  final List<AppFilterChipStripItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  /// When `true`, the strip becomes horizontally scrollable instead of
  /// distributing items with Expanded.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    if (scrollable) {
      return SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return _FilterPill(
              item: item,
              selected: item.id == selectedId,
              onTap: () => onSelected(item.id),
            );
          },
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _FilterPill(
              item: items[i],
              selected: items[i].id == selectedId,
              onTap: () => onSelected(items[i].id),
            ),
          ),
          if (i != items.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppFilterChipStripItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.panelRaised,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (item.icon != null) ...[
                Icon(
                  item.icon,
                  size: 15,
                  color: selected ? Colors.white : AppColors.mutedInk,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              if (item.count != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColors.panel,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${item.count}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected ? Colors.white : AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                      height: 1.2,
                    ),
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
