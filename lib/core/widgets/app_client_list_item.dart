import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_person_avatar.dart';

class AppClientListItem extends StatelessWidget {
  const AppClientListItem({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.footer,
    this.onTap,
    this.highlighted = false,
    this.titleStyle,
    this.titleMaxLines = 1,
    this.padding = const EdgeInsets.fromLTRB(2, 12, 2, 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.subtitleSpacing = 5,
    this.footerSpacing = 12,
  });

  final Widget leading;
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final Widget? footer;
  final VoidCallback? onTap;
  final bool highlighted;
  final TextStyle? titleStyle;
  final int titleMaxLines;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double subtitleSpacing;
  final double footerSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: highlighted ? _alpha(Colors.white, 0.08) : Colors.transparent,
          borderRadius: borderRadius,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          child: Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: titleMaxLines,
                            overflow: TextOverflow.ellipsis,
                            style:
                                titleStyle ??
                                theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          if (subtitle != null) ...[
                            SizedBox(height: subtitleSpacing),
                            subtitle!,
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
                if (footer != null) ...[
                  SizedBox(height: footerSpacing),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppClientPresenceAvatar extends StatelessWidget {
  const AppClientPresenceAvatar({
    super.key,
    required this.label,
    required this.fallback,
    this.imageUrl,
    this.isOnline = false,
    this.size = 56,
  });

  final String label;
  final String fallback;
  final String? imageUrl;
  final bool isOnline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = _clientAvatarPalette(label, fallback);

    return AppClientCardAvatar(
      label: label,
      fallback: fallback,
      imageUrl: imageUrl,
      size: size,
      status: isOnline ? AppAvatarStatus.online : AppAvatarStatus.none,
      backgroundColor: palette.background,
      borderColor: palette.border,
      foregroundColor: palette.foreground,
      useSolidBackground: true,
      showBorder: false,
    );
  }
}

({Color background, Color border, Color foreground}) _clientAvatarPalette(
  String label,
  String fallback,
) {
  const palettes = <({Color background, Color border, Color foreground})>[
    (
      background: Color(0xFF7CCF4E),
      border: Color(0xFF6BB63F),
      foreground: Colors.white,
    ),
    (
      background: Color(0xFFFFA43D),
      border: Color(0xFFE88F26),
      foreground: Colors.white,
    ),
    (
      background: Color(0xFFF06D9B),
      border: Color(0xFFD95A88),
      foreground: Colors.white,
    ),
    (
      background: Color(0xFF8B77F8),
      border: Color(0xFF7662E3),
      foreground: Colors.white,
    ),
    (
      background: Color(0xFF4FA8FF),
      border: Color(0xFF3994EC),
      foreground: Colors.white,
    ),
    (
      background: Color(0xFF34C7A5),
      border: Color(0xFF22B391),
      foreground: Colors.white,
    ),
    (
      background: Color(0xFFFF7A59),
      border: Color(0xFFE5684A),
      foreground: Colors.white,
    ),
    (
      background: Color(0xFFF2C14E),
      border: Color(0xFFD9A93B),
      foreground: Colors.white,
    ),
  ];

  final seed = '${label.trim().toUpperCase()}|${fallback.trim().toUpperCase()}';
  final hash = seed.codeUnits.fold<int>(0, (value, unit) => value + unit);
  return palettes[hash % palettes.length];
}

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);
