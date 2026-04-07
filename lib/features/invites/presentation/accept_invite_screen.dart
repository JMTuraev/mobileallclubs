import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/services/firebase_clients.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../application/invite_providers.dart';
import '../application/invite_service.dart';
import '../domain/gym_invite_summary.dart';

class AcceptInviteScreen extends ConsumerStatefulWidget {
  const AcceptInviteScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<AcceptInviteScreen> createState() => _AcceptInviteScreenState();
}

class _AcceptInviteScreenState extends ConsumerState<AcceptInviteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _didPrefillName = false;
  bool _isSubmitting = false;
  String? _submitError;
  String? _statusMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _prefillNameIfNeeded(GymInviteSummary invite) {
    final suggestedName = invite.staffData.fullName;
    if (_didPrefillName || suggestedName == null || suggestedName.isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didPrefillName) {
        return;
      }

      _fullNameController.text = suggestedName;
      setState(() => _didPrefillName = true);
    });
  }

  Future<void> _submit() async {
    final token = widget.token?.trim() ?? '';
    if (_isSubmitting || token.isEmpty || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submitError = null;
      _statusMessage = null;
    });

    try {
      await acceptInvite(
        auth: ref.read(firebaseAuthProvider),
        functions: ref.read(firebaseFunctionsProvider),
        token: token,
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
      );

      try {
        await ref
            .read(firebaseAuthProvider)
            .currentUser
            ?.sendEmailVerification();
        if (mounted) {
          setState(() {
            _statusMessage =
                'Account created. Verification email sent. Continue to verify email.';
          });
        }
      } on FirebaseAuthException catch (_) {
        if (mounted) {
          setState(() {
            _statusMessage =
                'Account created. Continue to verify email and resend if needed.';
          });
        }
      }

      if (!mounted) {
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        context.go(AppRoutes.verifyEmail);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(
        () => _submitError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final token = widget.token?.trim() ?? '';

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: token.isEmpty
                    ? const _InviteErrorCard(
                        title: 'Invite link unavailable',
                        message: 'Missing invite token.',
                      )
                    : ref
                          .watch(inviteTokenValidationProvider(token))
                          .when(
                            loading: () => const _InviteLoadingCard(),
                            error: (error, stackTrace) => _InviteErrorCard(
                              title: 'Invite unavailable',
                              message: error.toString(),
                            ),
                            data: (validation) {
                              if (!validation.valid ||
                                  validation.invite == null) {
                                return _InviteErrorCard(
                                  title: 'Invite unavailable',
                                  message:
                                      validation.errorMessage ??
                                      'Invite is no longer valid.',
                                );
                              }

                              final invite = validation.invite!;
                              _prefillNameIfNeeded(invite);

                              return Card(
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      28,
                                      24,
                                      24,
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Accept staff invite',
                                            style:
                                                theme.textTheme.headlineMedium,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Create the invited account using the exact validateInviteToken -> createUserWithEmailAndPassword -> acceptInvite flow from the working web source.',
                                            style: theme.textTheme.bodyLarge,
                                          ),
                                          const SizedBox(height: 20),
                                          _InfoRow(
                                            label: 'Email',
                                            value: invite.email ?? 'Unknown',
                                          ),
                                          _InfoRow(
                                            label: 'Role',
                                            value: invite.displayRole,
                                          ),
                                          if (invite.gymId != null)
                                            _InfoRow(
                                              label: 'Gym',
                                              value: invite.gymId!,
                                            ),
                                          const SizedBox(height: 20),
                                          TextFormField(
                                            controller: _fullNameController,
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: const InputDecoration(
                                              labelText: 'Full name',
                                            ),
                                            validator: (value) {
                                              if ((value?.trim() ?? '')
                                                  .isEmpty) {
                                                return 'Full name is required.';
                                              }

                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: true,
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: const InputDecoration(
                                              labelText: 'Password',
                                            ),
                                            validator: (value) {
                                              if ((value ?? '').length < 6) {
                                                return 'Password must be at least 6 characters.';
                                              }

                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          TextFormField(
                                            controller: _confirmController,
                                            obscureText: true,
                                            textInputAction:
                                                TextInputAction.done,
                                            onFieldSubmitted: (_) => _submit(),
                                            decoration: const InputDecoration(
                                              labelText: 'Confirm password',
                                            ),
                                            validator: (value) {
                                              if ((value ?? '') !=
                                                  _passwordController.text) {
                                                return 'Passwords do not match.';
                                              }

                                              return null;
                                            },
                                          ),
                                          if (_statusMessage != null) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              _statusMessage!,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: theme
                                                        .colorScheme
                                                        .primary,
                                                  ),
                                            ),
                                          ],
                                          if (_submitError != null) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              _submitError!,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color:
                                                        theme.colorScheme.error,
                                                  ),
                                            ),
                                          ],
                                          const SizedBox(height: 20),
                                          FilledButton(
                                            onPressed: _isSubmitting
                                                ? null
                                                : _submit,
                                            child: Text(
                                              _isSubmitting
                                                  ? 'Creating account...'
                                                  : 'Create account',
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextButton(
                                            onPressed: () =>
                                                context.go(AppRoutes.login),
                                            child: const Text(
                                              'Back to sign in',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteLoadingCard extends StatelessWidget {
  const _InviteLoadingCard();

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
            Text('Validating invite', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Checking the token against the production invite contract.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteErrorCard extends StatelessWidget {
  const _InviteErrorCard({required this.title, required this.message});

  final String title;
  final String message;

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
            Text(title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go(AppRoutes.login),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Go to sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyLarge,
          children: [
            TextSpan(
              text: '$label: ',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
