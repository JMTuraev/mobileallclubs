import 'package:flutter/material.dart';

import 'app_calendar.dart';
import '../theme/app_theme.dart';

enum AppDateRangeFilterPreset {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  allTime,
  custom,
}

class AppDateRangeFilter {
  const AppDateRangeFilter({
    required this.preset,
    required this.from,
    required this.to,
  });

  factory AppDateRangeFilter.today(DateTime now) {
    return appDateRangeFilterForPreset(AppDateRangeFilterPreset.today, now);
  }

  factory AppDateRangeFilter.allTime() {
    return const AppDateRangeFilter(
      preset: AppDateRangeFilterPreset.allTime,
      from: null,
      to: null,
    );
  }

  final AppDateRangeFilterPreset preset;
  final DateTime? from;
  final DateTime? to;
}

Future<AppDateRangeFilter?> showAppDateRangeFilterSheet({
  required BuildContext context,
  required String title,
  required AppDateRangeFilter selectedFilter,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  final option = await showDialog<AppDateRangeFilterPreset>(
    context: context,
    barrierColor: _alpha(AppColors.canvasStrong, 0.18),
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.74,
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFFFF), Color(0xFFF0F5FB)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _alpha(AppColors.border, 0.84)),
            boxShadow: [
              BoxShadow(
                color: _alpha(AppColors.canvasStrong, 0.12),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.secondary,
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              ...AppDateRangeFilterPreset.values.map(
                (preset) => _AppDateRangeFilterOptionTile(
                  label: _presetLabel(preset),
                  preset: preset,
                  selected: selectedFilter.preset == preset,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (option == null) {
    return null;
  }

  if (!context.mounted) {
    return null;
  }

  if (option == AppDateRangeFilterPreset.custom) {
    final now = DateUtils.dateOnly(DateTime.now());
    final initialRange = DateTimeRange(
      start: selectedFilter.from ?? now,
      end: selectedFilter.to ?? selectedFilter.from ?? now,
    );
    final picked = await showAppDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked == null) {
      return null;
    }

    return AppDateRangeFilter(
      preset: AppDateRangeFilterPreset.custom,
      from: DateUtils.dateOnly(picked.start),
      to: DateUtils.dateOnly(picked.end),
    );
  }

  return appDateRangeFilterForPreset(option, DateTime.now());
}

AppDateRangeFilter appDateRangeFilterForPreset(
  AppDateRangeFilterPreset preset,
  DateTime now,
) {
  final today = DateUtils.dateOnly(now);

  return switch (preset) {
    AppDateRangeFilterPreset.today => AppDateRangeFilter(
      preset: preset,
      from: today,
      to: today,
    ),
    AppDateRangeFilterPreset.yesterday => AppDateRangeFilter(
      preset: preset,
      from: today.subtract(const Duration(days: 1)),
      to: today.subtract(const Duration(days: 1)),
    ),
    AppDateRangeFilterPreset.last7Days => AppDateRangeFilter(
      preset: preset,
      from: today.subtract(const Duration(days: 6)),
      to: today,
    ),
    AppDateRangeFilterPreset.last30Days => AppDateRangeFilter(
      preset: preset,
      from: today.subtract(const Duration(days: 29)),
      to: today,
    ),
    AppDateRangeFilterPreset.thisMonth => AppDateRangeFilter(
      preset: preset,
      from: DateTime(today.year, today.month, 1),
      to: today,
    ),
    AppDateRangeFilterPreset.allTime => const AppDateRangeFilter(
      preset: AppDateRangeFilterPreset.allTime,
      from: null,
      to: null,
    ),
    AppDateRangeFilterPreset.custom => AppDateRangeFilter(
      preset: preset,
      from: today,
      to: today,
    ),
  };
}

String appDateRangeFilterLabel(AppDateRangeFilter filter) {
  return switch (filter.preset) {
    AppDateRangeFilterPreset.today => 'Today',
    AppDateRangeFilterPreset.yesterday => 'Yesterday',
    AppDateRangeFilterPreset.last7Days => 'Last 7 days',
    AppDateRangeFilterPreset.last30Days => 'Last 30 days',
    AppDateRangeFilterPreset.thisMonth => 'This month',
    AppDateRangeFilterPreset.allTime => 'All time',
    AppDateRangeFilterPreset.custom => formatAppDateRangeShort(
      filter.from,
      filter.to,
    ),
  };
}

String formatAppDateRangeShort(DateTime? from, DateTime? to) {
  if (from == null && to == null) {
    return 'All time';
  }
  if (from != null && to != null && DateUtils.isSameDay(from, to)) {
    return _formatShortDate(from);
  }

  final start = from == null ? 'Start' : _formatShortDate(from);
  final end = to == null ? 'Now' : _formatShortDate(to);
  return '$start - $end';
}

String formatAppDateRangeLong(DateTime? from, DateTime? to) {
  if (from == null && to == null) {
    return 'all time';
  }
  if (from != null && to != null && DateUtils.isSameDay(from, to)) {
    return _formatFullDate(from);
  }

  final start = from == null ? 'the beginning' : _formatFullDate(from);
  final end = to == null ? 'today' : _formatFullDate(to);
  return '$start to $end';
}

bool appDateRangeIncludesDate(AppDateRangeFilter filter, DateTime value) {
  if (filter.preset == AppDateRangeFilterPreset.allTime) {
    return true;
  }

  final target = DateUtils.dateOnly(value.toLocal());
  final from = filter.from == null ? null : DateUtils.dateOnly(filter.from!);
  final to = filter.to == null ? null : DateUtils.dateOnly(filter.to!);

  if (from != null && target.isBefore(from)) {
    return false;
  }
  if (to != null && target.isAfter(to)) {
    return false;
  }

  return true;
}

class _AppDateRangeFilterOptionTile extends StatelessWidget {
  const _AppDateRangeFilterOptionTile({
    required this.label,
    required this.preset,
    required this.selected,
  });

  final String label;
  final AppDateRangeFilterPreset preset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(preset),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
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
              border: Border.all(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.28)
                    : _alpha(AppColors.border, 0.78),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  preset == AppDateRangeFilterPreset.custom
                      ? Icons.edit_calendar_rounded
                      : Icons.calendar_today_rounded,
                  size: 18,
                  color: selected ? AppColors.canvasStrong : AppColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected ? AppColors.canvasStrong : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.canvasStrong,
                  )
                else
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: _alpha(AppColors.secondary, 0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _presetLabel(AppDateRangeFilterPreset preset) {
  return switch (preset) {
    AppDateRangeFilterPreset.today => 'Today',
    AppDateRangeFilterPreset.yesterday => 'Yesterday',
    AppDateRangeFilterPreset.last7Days => 'Last 7 days',
    AppDateRangeFilterPreset.last30Days => 'Last 30 days',
    AppDateRangeFilterPreset.thisMonth => 'This month',
    AppDateRangeFilterPreset.allTime => 'All time',
    AppDateRangeFilterPreset.custom => 'Custom range',
  };
}

String _formatShortDate(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')} ${_monthName(value.month)}';
}

String _formatFullDate(DateTime value) {
  return '${_weekdayName(value.weekday)}, ${value.day.toString().padLeft(2, '0')} ${_monthName(value.month)} ${value.year}';
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

String _weekdayName(int weekday) {
  const weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return weekdays[weekday - 1];
}

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);
