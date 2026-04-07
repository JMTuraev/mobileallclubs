import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../bootstrap/application/bootstrap_controller.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _isRefreshing = false;
  bool _isSigningOut = false;
  bool _isResending = false;
  String? _statusMessage;

  Future<void> _refreshVerificationStatus() async {
    if (_isRefreshing) {
      return;
    }

    setState(() => _isRefreshing = true);

    try {
      await ref.read(firebaseAuthProvider).currentUser?.reload();

      final currentUser = ref.read(firebaseAuthProvider).currentUser;
      if ((currentUser?.emailVerified ?? false) && mounted) {
        context.go('/app');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification refresh failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending) {
      return;
    }

    setState(() {
      _isResending = true;
      _statusMessage = null;
    });

    try {
      await ref.read(firebaseAuthProvider).currentUser?.sendEmailVerification();

      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Verification email sent again. Check the inbox for this account.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _statusMessage = 'Verification email failed: $error');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

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
    final theme = Theme.of(context);
    final email = session?.authUser.email ?? 'this account';

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AllClubs Mobile',
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Verify email',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Email/password login succeeded, but $email must be verified before entering the app.',
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.tonalIcon(
                            onPressed: _isResending
                                ? null
                                : _resendVerificationEmail,
                            icon: _isResending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.email_outlined),
                            label: Text(
                              _isResending
                                  ? 'Sending verification email...'
                                  : 'Send verification email again',
                            ),
                          ),
                          if (_statusMessage != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _statusMessage!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    _statusMessage!.startsWith(
                                      'Verification email failed',
                                    )
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _isRefreshing
                                ? null
                                : _refreshVerificationStatus,
                            icon: _isRefreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.mark_email_read_outlined),
                            label: Text(
                              _isRefreshing
                                  ? 'Checking verification...'
                                  : 'I verified my email',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isSigningOut ? null : _signOut,
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Sign out'),
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: 12),
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
                      ),
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
