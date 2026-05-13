import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_person_avatar.dart';
import '../domain/gym_staff_summary.dart';

class StaffMemberCard extends StatelessWidget {
  const StaffMemberCard({
    super.key,
    required this.member,
    required this.isBusy,
    required this.onEdit,
    required this.onToggleActive,
    required this.onRemove,
  });

  final GymStaffSummary member;
  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = member.isActiveByDefault;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppClientCardAvatar(
                  label: member.displayName,
                  fallback: member.initials,
                  imageUrl: member.imageUrl,
                  size: 54,
                  tone: isActive
                      ? AppClientAvatarTone.info
                      : AppClientAvatarTone.subtle,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          const _StaffTag(label: 'Staff'),
                          _StaffTag(
                            label: isActive ? 'Active' : 'Inactive',
                            foreground: isActive
                                ? const Color(0xFF7EC9FF)
                                : theme.colorScheme.onSurfaceVariant,
                            background: isActive
                                ? const Color(0x1F70B4FF)
                                : theme.colorScheme.surfaceContainerHighest,
                            border: isActive
                                ? const Color(0x6670B4FF)
                                : AppColors.border.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        member.displayPhone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StaffMenuButton(
                  isBusy: isBusy,
                  isActive: isActive,
                  onSelected: (action) {
                    switch (action) {
                      case _StaffMenuAction.edit:
                        onEdit();
                      case _StaffMenuAction.toggle:
                        onToggleActive(!isActive);
                      case _StaffMenuAction.remove:
                        onRemove();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _StaffMenuAction { edit, toggle, remove }

class _StaffMenuButton extends StatelessWidget {
  const _StaffMenuButton({
    required this.isBusy,
    required this.isActive,
    required this.onSelected,
  });

  final bool isBusy;
  final bool isActive;
  final ValueChanged<_StaffMenuAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: PopupMenuButton<_StaffMenuAction>(
        enabled: !isBusy,
        tooltip: 'More',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        onSelected: onSelected,
        color: const Color(0xFF171E29),
        elevation: 14,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        itemBuilder: (context) => [
          _staffMenuItem(
            context,
            value: _StaffMenuAction.edit,
            icon: Icons.edit_outlined,
            label: 'Edit',
          ),
          _staffMenuItem(
            context,
            value: _StaffMenuAction.toggle,
            icon: isActive ? Icons.toggle_off_rounded : Icons.toggle_on_rounded,
            label: isActive ? 'Disable' : 'Enable',
          ),
          _staffMenuItem(
            context,
            value: _StaffMenuAction.remove,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            isDanger: true,
          ),
        ],
        icon: isBusy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            : Icon(
                Icons.more_horiz_rounded,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
      ),
    );
  }
}

PopupMenuItem<_StaffMenuAction> _staffMenuItem(
  BuildContext context, {
  required _StaffMenuAction value,
  required IconData icon,
  required String label,
  bool isDanger = false,
}) {
  final theme = Theme.of(context);
  final color = isDanger
      ? theme.colorScheme.error
      : theme.colorScheme.onSurface;

  return PopupMenuItem<_StaffMenuAction>(
    value: value,
    child: Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _StaffTag extends StatelessWidget {
  const _StaffTag({
    required this.label,
    this.foreground,
    this.background,
    this.border,
  });

  final String label;
  final Color? foreground;
  final Color? background;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border ?? theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground ?? theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
