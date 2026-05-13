import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: _calendarThemeBuilder,
  );
}

Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDateRangePicker(
    context: context,
    initialDateRange: initialDateRange,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: _calendarThemeBuilder,
  );
}

Widget _calendarThemeBuilder(BuildContext context, Widget? child) {
  final theme = Theme.of(context);

  return Theme(
    data: theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        surface: AppColors.panel,
        surfaceContainerHigh: AppColors.panelRaised,
        onSurface: AppColors.ink,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        outline: AppColors.border,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        dividerColor: AppColors.border.withValues(alpha: 0.4),
        headerBackgroundColor: AppColors.panelRaised,
        headerForegroundColor: AppColors.ink,
        weekdayStyle: theme.textTheme.labelLarge?.copyWith(
          color: AppColors.secondary,
        ),
        dayStyle: theme.textTheme.bodyLarge?.copyWith(color: AppColors.ink),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.ink;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStatePropertyAll(AppColors.primary),
        todayBorder: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.8),
        ),
        rangeSelectionBackgroundColor: AppColors.primary.withValues(
          alpha: 0.16,
        ),
        rangePickerBackgroundColor: AppColors.panel,
        rangePickerHeaderBackgroundColor: AppColors.panelRaised,
        rangePickerHeaderForegroundColor: AppColors.ink,
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.secondary,
        ),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
        ),
      ),
    ),
    child: child ?? const SizedBox.shrink(),
  );
}
