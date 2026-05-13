import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Single canonical chip for showing a small metric / label / status across
/// the app. Replaces ad-hoc one-off pills in clients/sessions/packages/finance.
///
/// Tones map cleanly to brand state colors:
/// - [neutral]  — soft secondary tint, used for "not significant" metrics
/// - [primary]  — brand blue, used for active state / current selection
/// - [success]  — emerald, used for positive monetary values
/// - [warning]  — amber, used for debt / attention
/// - [danger]   — red, used for blocked / negative state
enum AppChipTone { neutral, primary, success, warning, danger }

/// Visual density of the chip — affects height and font size only.
enum AppChipSize { small, medium }

class AppDataChip extends StatelessWidget {
  const AppDataChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = AppChipTone.neutral,
    this.size = AppChipSize.medium,
    this.emphasis = false,
  });

  /// Visible text.
  final String label;

  /// Optional leading icon — kept small (14/16) for visual parity with text.
  final IconData? icon;

  /// Colour tone.
  final AppChipTone tone;

  /// Size variant.
  final AppChipSize size;

  /// When `true` uses a stronger background / border for emphasis.
  /// Default is the softer "container" variant.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _palette(tone);
    final isSmall = size == AppChipSize.small;

    final bg = emphasis
        ? palette.background
        : palette.background.withValues(alpha: 0.5);
    final border = emphasis
        ? palette.border
        : palette.border.withValues(alpha: 0.4);
    final fg = palette.foreground;
    final iconSize = isSmall ? 13.0 : 14.5;
    final fontSize = isSmall ? 11.5 : 12.5;
    final padH = isSmall ? 8.0 : 10.0;
    final padV = isSmall ? 4.0 : 5.5;

    return Container(
      height: isSmall ? 24 : 28,
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Tone palette for chip families. Background is the surface tint, foreground
/// is the text/icon, border is the 1px stroke when emphasized.
({Color background, Color border, Color foreground}) _palette(AppChipTone t) {
  switch (t) {
    case AppChipTone.primary:
      return (
        background: const Color(0xFFE2ECFE),
        border: AppColors.primary,
        foreground: AppColors.primaryDeep,
      );
    case AppChipTone.success:
      return (
        background: const Color(0xFFDCF6E8),
        border: AppColors.success,
        foreground: AppColors.successDeep,
      );
    case AppChipTone.warning:
      return (
        background: const Color(0xFFFEF1D8),
        border: AppColors.warning,
        foreground: AppColors.warningDeep,
      );
    case AppChipTone.danger:
      return (
        background: const Color(0xFFFCE0E5),
        border: AppColors.danger,
        foreground: AppColors.dangerDeep,
      );
    case AppChipTone.neutral:
      return (
        background: const Color(0xFFEEF2F7),
        border: AppColors.border,
        foreground: AppColors.mutedInk,
      );
  }
}
