import 'package:flutter/material.dart';

import '../../models/module_readiness_status.dart';
import '../theme/app_theme.dart';
import 'status_pill.dart';

class ModuleStatusCard extends StatelessWidget {
  const ModuleStatusCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
    required this.highlights,
    this.note,
  });

  final String title;
  final String description;
  final ModuleReadinessStatus status;
  final List<String> highlights;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              const SizedBox(width: 12),
              StatusPill(status: status),
            ],
          ),
          const SizedBox(height: 12),
          Text(description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 14),
          for (final highlight in highlights) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(highlight, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (note != null) ...[
            const Divider(height: 24),
            Text(note!, style: theme.textTheme.labelLarge),
          ],
        ],
      ),
    );
  }
}
