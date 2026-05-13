import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum AppClientAvatarTone { defaultTone, info, success, warning, danger, subtle }

/// Optional status ring around an avatar.
///
/// - [none] — no ring, default.
/// - [online] — emerald gradient ring, pulses gently.
/// - [active] — solid primary ring (e.g. ongoing session).
/// - [warning] — amber ring (e.g. has debt).
enum AppAvatarStatus { none, online, active, warning }

class AppClientCardAvatar extends StatelessWidget {
  const AppClientCardAvatar({
    super.key,
    required this.label,
    required this.fallback,
    this.imageUrl,
    this.badgeLabel,
    this.size = 56,
    this.tone = AppClientAvatarTone.defaultTone,
    this.status = AppAvatarStatus.none,
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
  final AppAvatarStatus status;
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
      status: status,
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

class AppPersonAvatar extends StatefulWidget {
  const AppPersonAvatar({
    super.key,
    required this.label,
    required this.fallback,
    this.imageUrl,
    this.badgeLabel,
    this.size = 56,
    this.status = AppAvatarStatus.none,
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
  final AppAvatarStatus status;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;
  final bool useSolidBackground;
  final bool showBorder;
  final Color badgeBackgroundColor;
  final Color? badgeBorderColor;
  final Color? badgeForegroundColor;

  @override
  State<AppPersonAvatar> createState() => _AppPersonAvatarState();
}

/// When `true`, [AppPersonAvatar] skips the continuous pulse ring animation.
///
/// Tests set this to `true` in setUp so `pumpAndSettle()` doesn't hang on the
/// infinite pulse. Visual goldens see a still ring (no halo) which is stable
/// across runs.
bool kAppPersonAvatarDisablePulse = false;

class _AppPersonAvatarState extends State<AppPersonAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  bool _animationsAllowed = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable =
        kAppPersonAvatarDisablePulse ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;
    _animationsAllowed = !disable;
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant AppPersonAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _syncPulse();
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  void _syncPulse() {
    final shouldPulse =
        widget.status == AppAvatarStatus.online && _animationsAllowed;
    if (shouldPulse) {
      _pulseController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      )..repeat(reverse: true);
    } else {
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedImageUrl = widget.imageUrl?.trim();
    final size = widget.size;
    final ring = _ringForStatus(widget.status);

    Widget avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.useSolidBackground ? widget.backgroundColor : null,
        gradient: widget.useSolidBackground
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _alpha(widget.backgroundColor, 0.95),
                  _alpha(widget.borderColor, 0.54),
                ],
              ),
        border: widget.showBorder
            ? Border.all(color: _alpha(widget.borderColor, 0.82))
            : null,
      ),
      child: ClipOval(
        child: SizedBox.expand(
          child: normalizedImageUrl != null && normalizedImageUrl.isNotEmpty
              ? Image(
                  image: NetworkImage(normalizedImageUrl),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _AppPersonAvatarFallback(
                    label: widget.label,
                    fallback: widget.fallback,
                    foregroundColor: widget.foregroundColor,
                  ),
                )
              : _AppPersonAvatarFallback(
                  label: widget.label,
                  fallback: widget.fallback,
                  foregroundColor: widget.foregroundColor,
                ),
        ),
      ),
    );

    if (ring != null) {
      avatar = Padding(
        padding: const EdgeInsets.all(3),
        child: avatar,
      );
    }

    return SizedBox(
      width: ring != null ? size + 6 : size,
      height: ring != null ? size + 6 : size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (ring != null)
            _RingFrame(
              size: size + 6,
              gradient: ring,
              pulse: _pulseController?.view,
            ),
          Center(child: avatar),
          if (widget.badgeLabel != null && widget.badgeLabel!.trim().isNotEmpty)
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
                    color: _alpha(widget.badgeBackgroundColor, 0.96),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _alpha(
                        widget.badgeBorderColor ?? widget.borderColor,
                        0.92,
                      ),
                    ),
                  ),
                  child: Text(
                    widget.badgeLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          widget.badgeForegroundColor ?? widget.foregroundColor,
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

/// Coloured ring drawn around a circular avatar. Animates when [pulse] is set.
class _RingFrame extends StatelessWidget {
  const _RingFrame({
    required this.size,
    required this.gradient,
    this.pulse,
  });

  final double size;
  final Gradient gradient;
  final Animation<double>? pulse;

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
      ),
    );

    if (pulse == null) return ring;

    return AnimatedBuilder(
      animation: pulse!,
      builder: (context, child) {
        final t = pulse!.value; // 0..1
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse halo
            Opacity(
              opacity: (1.0 - t) * 0.6,
              child: Transform.scale(
                scale: 1.0 + t * 0.18,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                  ),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: ring,
    );
  }
}

Gradient? _ringForStatus(AppAvatarStatus status) {
  switch (status) {
    case AppAvatarStatus.online:
      return AppGradients.success;
    case AppAvatarStatus.active:
      return AppGradients.primary;
    case AppAvatarStatus.warning:
      return AppGradients.warning;
    case AppAvatarStatus.none:
      return null;
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
