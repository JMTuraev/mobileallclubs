import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/firebase_clients.dart';
import '../../../core/widgets/app_shell_scaffold.dart';
import '../../../models/auth_bootstrap_models.dart';
import '../../bootstrap/application/bootstrap_controller.dart';

class AuthenticatedShellScreen extends ConsumerStatefulWidget {
  const AuthenticatedShellScreen({super.key});

  @override
  ConsumerState<AuthenticatedShellScreen> createState() =>
      _AuthenticatedShellScreenState();
}

class _AuthenticatedShellScreenState
    extends ConsumerState<AuthenticatedShellScreen> {
  bool _isSigningOut = false;

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bootstrapControllerProvider);
    final session = state.session;
    final userProfile = session?.userProfile;
    final theme = Theme.of(context);

    if (session == null || userProfile == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final canOpenStaff =
        session.gymId != null &&
        session.gymId!.isNotEmpty &&
        session.role == AllClubsRole.owner;

    return AppShellBody(
      maxWidth: 460,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(
                    'Real authenticated identity and tenant context resolved from the audited production contract.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                  _DetailRow(
                    label: 'Primary identity',
                    value: session.authUser.primaryIdentifier,
                  ),
                  _DetailRow(
                    label: 'Email verified',
                    value: session.authUser.emailVerified ? 'YES' : 'NO',
                  ),
                  _DetailRow(
                    label: 'Resolved role',
                    value: _roleLabel(userProfile.role),
                    detail: 'Source: ${userProfile.docPath}.role',
                  ),
                  _DetailRow(
                    label: 'Global user doc',
                    value: userProfile.docPath,
                  ),
                  if (userProfile.gymId != null)
                    _DetailRow(
                      label: 'Current gymId',
                      value: userProfile.gymId!,
                      detail: 'Source: ${userProfile.docPath}.gymId',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tenant context', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (session.isSuperAdmin) ...[
                    const _DetailRow(
                      label: 'Gym bootstrap',
                      value: 'SKIPPED',
                      detail:
                          'AuthContext stops after users/{uid} for super_admin.',
                    ),
                  ] else ...[
                    if (session.gymMembership != null)
                      _DetailRow(
                        label: 'Gym membership doc',
                        value: session.gymMembership!.docPath,
                        detail:
                            'Mirrored role: ${session.gymMembership!.roleValue ?? 'UNAVAILABLE'}',
                      ),
                    if (session.gym != null)
                      _DetailRow(
                        label: 'Gym doc',
                        value: session.gym!.docPath,
                        detail: session.gym!.name ?? 'Gym name unavailable',
                      ),
                  ],
                  _DetailRow(label: 'Auth method', value: state.loginMessage),
                  _DetailRow(
                    label: 'Gym resolution contract',
                    value: state.gymResolutionMessage,
                  ),
                  _DetailRow(
                    label: 'Role resolution contract',
                    value: state.roleResolutionMessage,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile actions', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 14),
                  if (canOpenStaff)
                    _ProfileActionTile(
                      icon: Icons.badge_rounded,
                      title: 'Open staff management',
                      subtitle:
                          'Owner-only staff module lives inside Profile in the new mobile shell.',
                      onTap: () => context.go(AppRoutes.staff),
                    ),
                  if (kDebugMode)
                    _ProfileActionTile(
                      icon: Icons.developer_mode_rounded,
                      title: 'Open developer diagnostics',
                      subtitle:
                          'Keep the Firebase runtime checks one tap away in debug mode.',
                      onTap: () => context.go(AppRoutes.firebaseDiagnostics),
                    ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _isSigningOut ? null : _signOut,
                    icon: _isSigningOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(_isSigningOut ? 'Signing out...' : 'Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.bodyLarge),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

String _roleLabel(AllClubsRole role) {
  return switch (role) {
    AllClubsRole.owner => 'owner',
    AllClubsRole.staff => 'staff',
    AllClubsRole.superAdmin => 'super_admin',
    AllClubsRole.unknown => 'unknown',
  };
}
