import 'package:flutter/material.dart';

import '../../models/module_readiness_status.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status, this.label});

  final ModuleReadinessStatus status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (background, foreground) = switch (status) {
      ModuleReadinessStatus.auditBlocked => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      ModuleReadinessStatus.foundationReady => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ModuleReadinessStatus.planned => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label ?? status.label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}
