import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLiquidGlass extends StatelessWidget {
  const AppLiquidGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.blurSigma = 22,
    this.gradient,
    this.border,
    this.boxShadow,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final double blurSigma;
  final Gradient? gradient;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient:
                  gradient ??
                  const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xE0263444), Color(0xBC141B24)],
                  ),
              border:
                  border ??
                  Border.all(color: AppColors.border.withValues(alpha: 0.72)),
              boxShadow:
                  boxShadow ??
                  [
                    BoxShadow(
                      color: Color(0x30000000),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: Offset(0, 2),
                    ),
                  ],
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
