import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../bootstrap/application/bootstrap_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _submissionError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    try {
      final userCredential = await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      final signedInUser = userCredential.user;

      if (!mounted) {
        return;
      }

      if (signedInUser != null && !signedInUser.emailVerified) {
        context.go('/auth/verify-email');
      }
    } on FirebaseAuthException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _submissionError = error.message ?? error.code);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _submissionError = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bootstrapControllerProvider);
    final theme = Theme.of(context);

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
                      child: Form(
                        key: _formKey,
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
                              'Sign in',
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Use your existing AllClubs email and password. After sign-in, mobile resolves users/{uid} and then the current gym context.',
                              style: theme.textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) {
                                  return 'Email is required.';
                                }
                                if (!trimmed.contains('@')) {
                                  return 'Enter a valid email.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Password',
                              ),
                              validator: (value) {
                                if ((value ?? '').isEmpty) {
                                  return 'Password is required.';
                                }

                                return null;
                              },
                            ),
                            if (_submissionError != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _submissionError!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => context.go('/auth/forgot-password'),
                              child: const Text('Forgot password?'),
                            ),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => context.go('/auth/register'),
                              child: const Text('Create account'),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed:
                                  state.interactiveLoginEnabled &&
                                      !_isSubmitting
                                  ? _submit
                                  : null,
                              child: Text(
                                _isSubmitting ? 'Signing in...' : 'Sign in',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.loginMessage,
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (kDebugMode) ...[
                              const SizedBox(height: 16),
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
      ),
    );
  }
}
