import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF16324F);
  static const mutedInk = Color(0xFF71839A);
  static const canvas = Color(0xFFF7FAFE);
  static const canvasStrong = Color(0xFF16324F);
  static const panel = Color(0xFFFFFFFF);
  static const panelRaised = Color(0xFFF0F5FB);
  static const border = Color(0xFFD6E1EC);
  static const primary = Color(0xFF3B82F6);
  static const secondary = Color(0xFF94A7BF);
  static const accent = Color(0xFF6D8CFF);
  static const danger = Color(0xFFD85F76);
  static const success = Color(0xFF3DBB7A);
}

class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.panel,
          onPrimary: Colors.white,
          onSecondary: AppColors.ink,
          onSurface: AppColors.ink,
          surfaceTint: Colors.transparent,
          outline: AppColors.border,
          error: AppColors.danger,
          primaryContainer: const Color(0xFFDCE8FF),
          onPrimaryContainer: AppColors.ink,
          secondaryContainer: const Color(0xFFE8EFF7),
          onSecondaryContainer: AppColors.ink,
          surfaceContainerHighest: AppColors.panelRaised,
          onSurfaceVariant: AppColors.mutedInk,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      dividerColor: AppColors.border,
    );

    final textTheme = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
        height: 1.08,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.1,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.18,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 15,
        color: AppColors.ink,
        height: 1.35,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14,
        color: AppColors.mutedInk,
        height: 1.35,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontSize: 12,
        color: AppColors.mutedInk,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontSize: 11,
        color: AppColors.mutedInk,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
          side: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: AppColors.panel,
        indicatorColor: scheme.primaryContainer.withValues(alpha: 0.92),
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.canvasStrong,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.panelRaised,
        hintStyle: textTheme.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.canvasStrong,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark() => light();
}
