import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void handleAppRouteBack(
  BuildContext context, {
  required String fallbackLocation,
}) {
  final router = GoRouter.of(context);
  if (router.canPop()) {
    router.pop();
    return;
  }

  final target = fallbackLocation.trim();
  if (target.isEmpty) {
    return;
  }

  final currentLocation = GoRouterState.of(context).uri.toString();
  if (currentLocation == target) {
    return;
  }

  router.go(target);
}

class AppRouteBackScope extends StatelessWidget {
  const AppRouteBackScope({
    super.key,
    required this.fallbackLocation,
    required this.child,
  });

  final String fallbackLocation;
  final Widget child;

  void _handleBack(BuildContext context) {
    handleAppRouteBack(context, fallbackLocation: fallbackLocation);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        _handleBack(context);
      },
      child: child,
    );
  }
}
