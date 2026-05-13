import 'package:flutter/material.dart';

enum AppClientAvatarTone { defaultTone, info, success, warning, danger, subtle }

class AppClientCardAvatar extends StatelessWidget {
  const AppClientCardAvatar({
    super.key,
    required this.label,
    required this.fallback,
    this.imageUrl,
    this.badgeLabel,
    this.size = 56,
    this.tone = AppClientAvatarTone.defaultTone,
    this.backgroundColor,
    this.borderColor,
    this.foregroundColor,
    this.useSolidBackground = false,
    this.showBorder = true,
    this.badgeBackgroundColor = const Color(0xFF0E1620),
    this.badgeBorderColor,
    this.badgeForegroundColor,
  });

  final String label;
  final String fallback;
  final String? imageUrl;
  final String? badgeLabel;
  final double size;
  final AppClientAvatarTone tone;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? foregroundColor;
  final bool useSolidBackground;
  final bool showBorder;
  final Color badgeBackgroundColor;
  final Color? badgeBorderColor;
  final Color? badgeForegroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteForTone(tone);

    return AppPersonAvatar(
      label: label,
      fallback: fallback,
      imageUrl: imageUrl,
      badgeLabel: badgeLabel,
      size: size,
      backgroundColor: backgroundColor ?? palette.background,
      borderColor: borderColor ?? palette.border,
      foregroundColor: foregroundColor ?? palette.foreground,
      useSolidBackground: useSolidBackground,
      showBorder: showBorder,
      badgeBackgroundColor: badgeBackgroundColor,
      badgeBorderColor: badgeBorderColor ?? palette.border,
      badgeForegroundColor: badgeForegroundColor ?? palette.foreground,
    );
  }
}

class AppPersonAvatar extends StatelessWidget {
  const AppPersonAvatar({
    super.key,
    required this.label,
    required this.fallback,
    this.imageUrl,
    this.badgeLabel,
    this.size = 56,
    this.backgroundColor = const Color(0xFF25303B),
    this.borderColor = const Color(0xFF465568),
    this.foregroundColor = const Color(0xFFE5EDF6),
    this.useSolidBackground = false,
    this.showBorder = true,
    this.badgeBackgroundColor = const Color(0xFF0E1620),
    this.badgeBorderColor,
    this.badgeForegroundColor,
  });

  final String label;
  final String fallback;
  final String? imageUrl;
  final String? badgeLabel;
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final bool useSolidBackground;
  final bool showBorder;
  final Color badgeBackgroundColor;
  final Color? badgeBorderColor;
  final Color? badgeForegroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedImageUrl = imageUrl?.trim();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: useSolidBackground ? backgroundColor : null,
              gradient: useSolidBackground
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _alpha(backgroundColor, 0.95),
                        _alpha(borderColor, 0.54),
                      ],
                    ),
              border: showBorder
                  ? Border.all(color: _alpha(borderColor, 0.82))
                  : null,
            ),
            child: ClipOval(
              child: SizedBox.expand(
                child:
                    normalizedImageUrl != null && normalizedImageUrl.isNotEmpty
                    ? Image(
                        image: NetworkImage(normalizedImageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _AppPersonAvatarFallback(
                          label: label,
                          fallback: fallback,
                          foregroundColor: foregroundColor,
                        ),
                      )
                    : _AppPersonAvatarFallback(
                        label: label,
                        fallback: fallback,
                        foregroundColor: foregroundColor,
                      ),
              ),
            ),
          ),
          if (badgeLabel != null && badgeLabel!.trim().isNotEmpty)
            Positioned(
              left: 2,
              right: 2,
              bottom: -7,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _alpha(badgeBackgroundColor, 0.96),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _alpha(badgeBorderColor ?? borderColor, 0.92),
                    ),
                  ),
                  child: Text(
                    badgeLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeForegroundColor ?? foregroundColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 9.2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppPersonAvatarFallback extends StatelessWidget {
  const _AppPersonAvatarFallback({
    required this.label,
    required this.fallback,
    required this.foregroundColor,
  });

  final String label;
  final String fallback;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      alignment: Alignment.center,
      child: Text(
        _initialsFromLabel(label, fallback),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: foregroundColor,
        ),
      ),
    );
  }
}

String _initialsFromLabel(String value, String fallback) {
  final words = value
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);

  if (words.isEmpty) {
    return fallback;
  }

  if (words.length == 1) {
    return words.first
        .substring(0, words.first.length.clamp(0, 2))
        .toUpperCase();
  }

  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

({Color background, Color border, Color foreground}) _paletteForTone(
  AppClientAvatarTone tone,
) {
  return switch (tone) {
    AppClientAvatarTone.info => (
      background: const Color(0xFF18344A),
      border: const Color(0xFF70B4FF),
      foreground: const Color(0xFF7EC9FF),
    ),
    AppClientAvatarTone.success => (
      background: const Color(0xFF233628),
      border: const Color(0xFF87C49A),
      foreground: const Color(0xFF9EE0B6),
    ),
    AppClientAvatarTone.warning => (
      background: const Color(0xFF3D3120),
      border: const Color(0xFFF2B85B),
      foreground: const Color(0xFFF5D28E),
    ),
    AppClientAvatarTone.danger => (
      background: const Color(0xFF402726),
      border: const Color(0xFFE48764),
      foreground: const Color(0xFFF1B299),
    ),
    AppClientAvatarTone.subtle => (
      background: const Color(0xFF2A3340),
      border: const Color(0xFF718398),
      foreground: const Color(0xFFD4DEEA),
    ),
    AppClientAvatarTone.defaultTone => (
      background: const Color(0xFF25303B),
      border: const Color(0xFF465568),
      foreground: const Color(0xFFE5EDF6),
    ),
  };
}

Color _alpha(Color color, double opacity) => color.withValues(alpha: opacity);
