import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../../core/widgets/section_title.dart';
import '../application/bootstrap_controller.dart';

class BootstrapGateScreen extends ConsumerStatefulWidget {
  const BootstrapGateScreen({super.key});

  @override
  ConsumerState<BootstrapGateScreen> createState() =>
      _BootstrapGateScreenState();
}

class _BootstrapGateScreenState extends ConsumerState<BootstrapGateScreen> {
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
    final theme = Theme.of(context);
    final title = state.hasBootstrapError
        ? 'Startup unavailable'
        : 'Preparing secure session';
    final message = state.hasBootstrapError
        ? (state.message ?? 'Firebase startup could not complete.')
        : 'Checking Firebase bootstrap and restoring the current session.';
    final hasRecoverableSessionError =
        state.hasBootstrapError &&
        ((state.message?.contains('users/') ?? false) ||
            (state.message?.contains('gyms/') ?? false));

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: state.hasBootstrapError
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Icon(
                            state.hasBootstrapError
                                ? Icons.error_outline_rounded
                                : Icons.shield_rounded,
                            color: state.hasBootstrapError
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'AllClubs Mobile',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(title, style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        Text(message, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 20),
                        if (state.isLoading) ...[
                          const LinearProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            'This route stays protected until FirebaseAuth returns the current session state.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ] else ...[
                          SectionTitle(
                            title: 'Bootstrap details',
                            subtitle: state.message ?? 'No additional details.',
                          ),
                          if (hasRecoverableSessionError) ...[
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _isSigningOut ? null : _signOut,
                              icon: _isSigningOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.logout_rounded),
                              label: Text(
                                _isSigningOut
                                    ? 'Signing out...'
                                    : 'Sign out and try another account',
                              ),
                            ),
                          ],
                          if (kDebugMode) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  context.go('/dev/firebase-diagnostics'),
                              icon: const Icon(Icons.developer_mode_rounded),
                              label: const Text(
                                'Open Developer Firebase Diagnostics',
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
