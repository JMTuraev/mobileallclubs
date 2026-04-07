import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/firebase_clients.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';
import '../application/invite_providers.dart';
import '../application/invite_service.dart';
import '../domain/gym_invite_summary.dart';

class InvitesScreen extends ConsumerStatefulWidget {
  const InvitesScreen({super.key});

  @override
  ConsumerState<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final Set<String> _busyInviteIds = <String>{};

  bool _isSubmitting = false;
  String? _statusMessage;
  bool _statusIsError = false;
  String? _latestToken;

  @override
  void dispose() {
    _emailController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _setStatus(String message, {required bool isError, String? token}) {
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
      _latestToken = token;
    });
  }

  Future<void> _submitInvite(ResolvedAuthSession? session) async {
    if (_isSubmitting ||
        !_formKey.currentState!.validate() ||
        session == null) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
      _statusIsError = false;
      _latestToken = null;
    });

    try {
      final result = await sendInvite(
        functions: ref.read(firebaseFunctionsProvider),
        request: SendInviteRequest(
          email: _emailController.text.trim(),
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
          gymName: session.gym?.name,
          inviterName:
              session.userProfile?.fullName ??
              session.authUser.displayName ??
              session.authUser.email,
        ),
      );

      if (!mounted) {
        return;
      }

      _emailController.clear();
      _fullNameController.clear();
      _phoneController.clear();

      if (result.assignedExistingUser) {
        _setStatus(
          'Existing account was assigned directly to the current gym.',
          isError: false,
        );
      } else {
        _setStatus(
          'Invite created successfully.',
          isError: false,
          token: result.token,
        );
      }

      ref.invalidate(gymInvitesProvider);
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
        setState(() => _isSubmitting = false);
      }
    }
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

  Future<void> _resendInviteAction(GymInviteSummary invite) async {
    if (_busyInviteIds.contains(invite.id)) {
      return;
    }

    final shouldProceed = await _confirmAction(
      title: 'Resend invite?',
      message:
          'This resets the token and expiry using the exact resendInvite callable.',
    );
    if (shouldProceed != true) {
      return;
    }

    setState(() => _busyInviteIds.add(invite.id));

    try {
      final result = await resendInvite(
        functions: ref.read(firebaseFunctionsProvider),
        inviteId: invite.id,
      );

      if (!mounted) {
        return;
      }

      _setStatus(
        'Invite resent successfully.',
        isError: false,
        token: result.token,
      );
      ref.invalidate(gymInvitesProvider);
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
        setState(() => _busyInviteIds.remove(invite.id));
      }
    }
  }

  Future<void> _cancelInviteAction(GymInviteSummary invite) async {
    if (_busyInviteIds.contains(invite.id)) {
      return;
    }

    final shouldProceed = await _confirmAction(
      title: 'Cancel invite?',
      message:
          'This uses the exact cancelInvite callable and marks the invite as cancelled.',
    );
    if (shouldProceed != true) {
      return;
    }

    setState(() => _busyInviteIds.add(invite.id));

    try {
      await cancelInvite(
        functions: ref.read(firebaseFunctionsProvider),
        inviteId: invite.id,
      );

      if (!mounted) {
        return;
      }

      _setStatus('Invite cancelled.', isError: false);
      ref.invalidate(gymInvitesProvider);
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
        setState(() => _busyInviteIds.remove(invite.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(bootstrapControllerProvider).session;
    final invitesAsync = ref.watch(gymInvitesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.staff),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text('Staff invites'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(gymInvitesProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: AppBackdrop(
        child: SafeArea(
          top: false,
          child: AppShellBody(
            child: !_canManageInvites(session)
                ? _InviteAccessBlocked(
                    onBack: () => context.go(AppRoutes.staff),
                  )
                : ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Send staff invite',
                                  style: theme.textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Uses the exact sendInvite callable from the working backend contract.',
                                  style: theme.textTheme.bodyLarge,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _fullNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Full name',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) =>
                                      _submitInvite(session),
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                  ),
                                  validator: (value) {
                                    final trimmed = value?.trim() ?? '';
                                    if (trimmed.isEmpty) {
                                      return 'Email is required';
                                    }

                                    if (!RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    ).hasMatch(trimmed)) {
                                      return 'Invalid email format';
                                    }

                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                FilledButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () => _submitInvite(session),
                                  child: Text(
                                    _isSubmitting
                                        ? 'Sending invite...'
                                        : 'Send invite',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 12),
                        _InviteStatusCard(
                          title: _statusIsError
                              ? 'Invite action failed'
                              : 'Invites',
                          message: _statusMessage!,
                          token: _latestToken,
                          isError: _statusIsError,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invite history',
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Live list from the root invites collection filtered by the current gym via getGymInvites.',
                                style: theme.textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 16),
                              invitesAsync.when(
                                loading: () => const LinearProgressIndicator(),
                                error: (error, stackTrace) => _InlineMessage(
                                  text: error.toString(),
                                  color: theme.colorScheme.error,
                                ),
                                data: (invites) {
                                  if (invites.isEmpty) {
                                    return const Text('No invites found.');
                                  }

                                  return Column(
                                    children: invites
                                        .map(
                                          (invite) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            child: _InviteCard(
                                              invite: invite,
                                              isBusy: _busyInviteIds.contains(
                                                invite.id,
                                              ),
                                              onResend: invite.isPending
                                                  ? () => _resendInviteAction(
                                                      invite,
                                                    )
                                                  : null,
                                              onCancel: invite.isPending
                                                  ? () => _cancelInviteAction(
                                                      invite,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                        )
                                        .toList(growable: false),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

bool _canManageInvites(ResolvedAuthSession? session) {
  if (session == null) {
    return false;
  }

  final gymId = session.gymId;
  return gymId != null &&
      gymId.isNotEmpty &&
      session.role == AllClubsRole.owner;
}

class _InviteAccessBlocked extends StatelessWidget {
  const _InviteAccessBlocked({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invites unavailable', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(
              'This module is available only for owner accounts with a resolved gym context.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to staff'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteStatusCard extends StatelessWidget {
  const _InviteStatusCard({
    required this.title,
    required this.message,
    required this.isError,
    this.token,
  });

  final String title;
  final String message;
  final bool isError;
  final String? token;

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
            if (token != null && token!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Latest invite token',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isError
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                token!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isError
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invite,
    required this.isBusy,
    this.onResend,
    this.onCancel,
  });

  final GymInviteSummary invite;
  final bool isBusy;
  final VoidCallback? onResend;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.45,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(invite.displayName, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(invite.email ?? 'No email', style: theme.textTheme.bodyLarge),
          if (invite.displayPhone != null) ...[
            const SizedBox(height: 6),
            Text(invite.displayPhone!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InviteChip(label: invite.displayRole),
              _InviteChip(label: invite.displayStatus),
              if (invite.expiresAt != null)
                _InviteChip(label: 'Expires ${_formatDate(invite.expiresAt)}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: isBusy ? null : onResend,
                child: Text(isBusy ? 'Working...' : 'Resend'),
              ),
              FilledButton.tonal(
                onPressed: isBusy ? null : onCancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InviteChip extends StatelessWidget {
  const _InviteChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) {
    return 'unknown';
  }

  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
