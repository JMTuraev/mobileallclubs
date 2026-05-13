import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/developer_tools.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/firebase_clients.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/create_staff_service.dart';
import '../application/staff_providers.dart';
import '../domain/gym_staff_summary.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  bool _isSigningOut = false;
  String? _statusMessage;
  bool _statusIsError = false;
  final Set<String> _busyStaffIds = <String>{};
  final Set<String> _removedStaffIds = <String>{};
  final Map<String, bool> _activeOverrides = <String, bool>{};
  final Map<String, String> _fullNameOverrides = <String, String>{};
  final Map<String, String> _phoneOverrides = <String, String>{};

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }

    setState(() => _isSigningOut = true);

    try {
      await ref.read(firebaseAuthProvider).signOut();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign-out failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  void _setStatus(String message, {required bool isError}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _setMemberActive(
    GymStaffSummary member, {
    required bool isActive,
  }) async {
    if (_busyStaffIds.contains(member.id)) {
      return;
    }

    final shouldProceed = await _confirmAction(
      title: isActive ? 'Reactivate staff?' : 'Deactivate staff?',
      message: isActive
          ? 'This uses the exact deactivateStaff callable with isActive=true.'
          : 'This uses the exact deactivateStaff callable with isActive=false.',
    );

    if (shouldProceed != true) {
      return;
    }

    setState(() {
      _busyStaffIds.add(member.id);
    });

    try {
      await setStaffActiveState(
        functions: ref.read(firebaseFunctionsProvider),
        userId: member.id,
        isActive: isActive,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(activeStaffIdsProvider);
      _setStatus(
        isActive ? 'Staff reactivated.' : 'Staff deactivated.',
        isError: false,
      );
      setState(() {
        _activeOverrides[member.id] = isActive;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyStaffIds.remove(member.id);
        });
      }
    }
  }

  Future<void> _removeMember(GymStaffSummary member) async {
    if (_busyStaffIds.contains(member.id)) {
      return;
    }

    final shouldProceed = await _confirmAction(
      title: 'Remove staff?',
      message:
          'This uses the exact removeStaff callable from the working web source-of-truth.',
    );

    if (shouldProceed != true) {
      return;
    }

    setState(() {
      _busyStaffIds.add(member.id);
    });

    try {
      await removeStaffMember(
        functions: ref.read(firebaseFunctionsProvider),
        userId: member.id,
      );

      if (!mounted) {
        return;
      }

      ref.invalidate(activeStaffIdsProvider);
      ref.invalidate(currentGymStaffStreamProvider);
      _setStatus('Staff removed.', isError: false);
      setState(() {
        _removedStaffIds.add(member.id);
        _activeOverrides.remove(member.id);
        _fullNameOverrides.remove(member.id);
        _phoneOverrides.remove(member.id);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _setStatus(
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyStaffIds.remove(member.id);
        });
      }
    }
  }

  Future<void> _editMember(GymStaffSummary member) async {
    if (_busyStaffIds.contains(member.id)) {
      return;
    }

    final fullNameController = TextEditingController(
      text: member.fullName ?? '',
    );
    final phoneController = TextEditingController(text: member.phone ?? '');

    final didSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        var isSaving = false;
        String? dialogError;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit staff'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.email ?? member.id,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: fullNameController,
                    enabled: !isSaving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    enabled: !isSaving,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  if (dialogError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      dialogError!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() {
                          isSaving = true;
                          dialogError = null;
                        });

                        try {
                          await updateStaffMember(
                            functions: ref.read(firebaseFunctionsProvider),
                            request: UpdateStaffRequest(
                              userId: member.id,
                              fullName: fullNameController.text.trim(),
                              phone: phoneController.text.trim(),
                            ),
                          );

                          if (!context.mounted) {
                            return;
                          }

                          Navigator.of(dialogContext).pop(true);
                        } catch (error) {
                          setDialogState(() {
                            isSaving = false;
                            dialogError = error.toString().replaceFirst(
                              'Exception: ',
                              '',
                            );
                          });
                        }
                      },
                child: Text(isSaving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        );
      },
    );

    fullNameController.dispose();
    phoneController.dispose();

    if (didSave == true && mounted) {
      ref.invalidate(currentGymStaffStreamProvider);
      _setStatus('Staff updated.', isError: false);
      setState(() {
        _fullNameOverrides[member.id] = fullNameController.text.trim();
        _phoneOverrides[member.id] = phoneController.text.trim();
      });
    }
  }

  bool _resolveIsActive(
    GymStaffSummary member,
    AsyncValue<Set<String>> activeStaffIdsAsync,
  ) {
    final localOverride = _activeOverrides[member.id];
    if (localOverride != null) {
      return localOverride;
    }

    return activeStaffIdsAsync.maybeWhen(
      data: (activeIds) => activeIds.contains(member.id),
      orElse: () => member.isActiveByDefault,
    );
  }

  GymStaffSummary _applyLocalOverrides(
    GymStaffSummary member,
    AsyncValue<Set<String>> activeStaffIdsAsync,
  ) {
    return GymStaffSummary(
      id: member.id,
      fullName: _fullNameOverrides[member.id] ?? member.fullName,
      firstName: member.firstName,
      lastName: member.lastName,
      phone: _phoneOverrides[member.id] ?? member.phone,
      email: member.email,
      imageUrl: member.imageUrl,
      roleValue: member.roleValue,
      isActive: _resolveIsActive(member, activeStaffIdsAsync),
      createdAtEpochMillis: member.createdAtEpochMillis,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final staffAsync = ref.watch(currentGymStaffStreamProvider);
    final activeStaffIdsAsync = ref.watch(activeStaffIdsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.app),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text('Staff'),
        actions: [
          IconButton(
            onPressed: _canAccessStaff(session)
                ? () => context.go(AppRoutes.staffInvites)
                : null,
            icon: const Icon(Icons.mail_outline_rounded),
            tooltip: 'Staff invites',
          ),
          IconButton(
            onPressed: _canAccessStaff(session)
                ? () => context.go(AppRoutes.createStaff)
                : null,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Create staff',
          ),
          IconButton(
            onPressed: _isSigningOut ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AppShellBody(
            child: !_canAccessStaff(session)
                ? _StaffAccessBlocked(onBack: () => context.go(AppRoutes.app))
                : staffAsync.when(
                    loading: () =>
                        _StaffLoadingCard(gymName: session?.gym?.name),
                    error: (error, stackTrace) =>
                        _StaffErrorCard(message: error.toString()),
                    data: (staff) {
                      final visibleStaff = staff
                          .where(
                            (member) => !_removedStaffIds.contains(member.id),
                          )
                          .map(
                            (member) => _applyLocalOverrides(
                              member,
                              activeStaffIdsAsync,
                            ),
                          )
                          .toList(growable: false);

                      final activeCount = visibleStaff
                          .where((member) => member.isActiveByDefault)
                          .length;

                      return ListView(
                        children: [
                          if (_statusMessage != null) ...[
                            _StaffStatusCard(
                              title: _statusIsError
                                  ? 'Staff action failed'
                                  : 'Staff',
                              message: _statusMessage!,
                              isError: _statusIsError,
                            ),
                            const SizedBox(height: 12),
                          ],
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session?.gym?.name ?? 'Staff',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Live staff list from gyms/${session?.gymId}/users, with active-state synced from the exact getActiveStaff callable so owner actions reflect the audited backend contract.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _InfoChip(
                                        icon: Icons.groups_rounded,
                                        label: '${visibleStaff.length} staff',
                                      ),
                                      _InfoChip(
                                        icon: Icons.check_circle_rounded,
                                        label: '$activeCount active',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: () =>
                                        context.go(AppRoutes.staffInvites),
                                    icon: const Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                    label: const Text('Manage invites'),
                                  ),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () =>
                                        context.go(AppRoutes.createStaff),
                                    icon: const Icon(
                                      Icons.person_add_alt_1_rounded,
                                    ),
                                    label: const Text('Create staff'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (visibleStaff.isEmpty)
                            const _StaffEmptyCard()
                          else
                            ...visibleStaff.map(
                              (member) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _StaffCard(
                                  member: member,
                                  isBusy: _busyStaffIds.contains(member.id),
                                  onEdit: () => _editMember(member),
                                  onDeactivate: member.isActiveByDefault
                                      ? () => _setMemberActive(
                                          member,
                                          isActive: false,
                                        )
                                      : null,
                                  onReactivate: member.isActiveByDefault
                                      ? null
                                      : () => _setMemberActive(
                                          member,
                                          isActive: true,
                                        ),
                                  onRemove: () => _removeMember(member),
                                ),
                              ),
                            ),
                          if (showDeveloperDiagnosticsShortcut) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  openDeveloperDiagnostics(context),
                              icon: const Icon(Icons.developer_mode_rounded),
                              label: const Text(
                                'Open Developer Firebase Diagnostics',
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

bool _canAccessStaff(ResolvedAuthSession? session) {
  if (session == null) {
    return false;
  }

  final gymId = session.gymId;

  return gymId != null &&
      gymId.isNotEmpty &&
      session.role == AllClubsRole.owner;
}

class _StaffLoadingCard extends StatelessWidget {
  const _StaffLoadingCard({this.gymName});

  final String? gymName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gymName ?? 'Staff', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Loading current gym staff...',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffErrorCard extends StatelessWidget {
  const _StaffErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Staff unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'The staff stream failed for the current gym.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffEmptyCard extends StatelessWidget {
  const _StaffEmptyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('No staff found', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'The working web /app/staffs route returned no gym-user documents with role == staff.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffAccessBlocked extends StatelessWidget {
  const _StaffAccessBlocked({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Staff unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'This module is available only for owner accounts with a resolved gym context, matching the working web route guard.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to account'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.member,
    required this.isBusy,
    required this.onEdit,
    required this.onRemove,
    this.onDeactivate,
    this.onReactivate,
  });

  final GymStaffSummary member;
  final bool isBusy;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback? onDeactivate;
  final VoidCallback? onReactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(member: member),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.displayName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      const _RoleChip(label: 'Staff'),
                      _RoleChip(
                        label: member.isActiveByDefault ? 'Active' : 'Inactive',
                        isActive: member.isActiveByDefault,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(member.displayPhone, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: isBusy ? null : onEdit,
                        child: const Text('Edit'),
                      ),
                      if (member.isActiveByDefault)
                        FilledButton.tonal(
                          onPressed: isBusy ? null : onDeactivate,
                          child: Text(isBusy ? 'Working...' : 'Deactivate'),
                        )
                      else
                        FilledButton.tonal(
                          onPressed: isBusy ? null : onReactivate,
                          child: Text(isBusy ? 'Working...' : 'Reactivate'),
                        ),
                      FilledButton.tonal(
                        onPressed: isBusy ? null : onRemove,
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffStatusCard extends StatelessWidget {
  const _StaffStatusCard({
    required this.title,
    required this.message,
    required this.isError,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: isError
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isError
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.member});

  final GymStaffSummary member;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = member.imageUrl?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CircleAvatar(radius: 28, foregroundImage: NetworkImage(imageUrl));
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Text(
        member.initials,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, this.isActive});

  final String label;
  final bool? isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final active = isActive;
    final background = switch (active) {
      true => colorScheme.primaryContainer,
      false => colorScheme.surfaceContainerHighest,
      null => colorScheme.secondaryContainer,
    };
    final foreground = switch (active) {
      true => colorScheme.onPrimaryContainer,
      false => colorScheme.onSurfaceVariant,
      null => colorScheme.onSecondaryContainer,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: theme.textTheme.labelLarge)),
        ],
      ),
    );
  }
}
