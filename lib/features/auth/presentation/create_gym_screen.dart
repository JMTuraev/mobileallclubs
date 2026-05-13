import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_bootstrap_resolver.dart';
import '../../../core/services/firebase_clients.dart';
import '../../../core/services/onboarding_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_backdrop.dart';
import '../../bootstrap/application/bootstrap_controller.dart';

class CreateGymScreen extends ConsumerStatefulWidget {
  const CreateGymScreen({super.key});

  @override
  ConsumerState<CreateGymScreen> createState() => _CreateGymScreenState();
}

class _CreateGymScreenState extends ConsumerState<CreateGymScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+998');
  final _clubNameController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isSubmitting = false;
  bool _isClearingLock = false;
  String? _errorMessage;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _clubNameController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String _formatPhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('998')) {
      digits = digits.substring(3);
    }

    var formatted = '+998';

    if (digits.isNotEmpty) {
      formatted += ' ${digits.substring(0, digits.length.clamp(0, 2))}';
    }
    if (digits.length > 2) {
      formatted += ' ${digits.substring(2, digits.length.clamp(2, 5))}';
    }
    if (digits.length > 5) {
      formatted += ' ${digits.substring(5, digits.length.clamp(5, 7))}';
    }
    if (digits.length > 7) {
      formatted += ' ${digits.substring(7, digits.length.clamp(7, 9))}';
    }

    return formatted;
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      setState(() => _errorMessage = 'Auth session is not ready.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await createGymAndUser(
        firebaseUser: firebaseUser,
        functions: ref.read(firebaseFunctionsProvider),
        request: CreateGymRequest(
          name: _clubNameController.text.trim(),
          city: _cityController.text.trim(),
          phone: _phoneController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        ),
      );

      ref.invalidate(resolvedAuthSessionStreamProvider);
      ref.invalidate(bootstrapControllerProvider);

      if (!mounted) {
        return;
      }

      if (result.success) {
        context.go('/bootstrap');
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error.toString();
      if (message.contains('already-exists') ||
          message.contains('User already has a gym')) {
        ref.invalidate(resolvedAuthSessionStreamProvider);
        ref.invalidate(bootstrapControllerProvider);
        context.go('/bootstrap');
      } else {
        setState(() => _errorMessage = message);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _clearLockAndRetry() async {
    if (_isSubmitting || _isClearingLock) {
      return;
    }

    final firebaseUser = ref.read(firebaseAuthProvider).currentUser;
    if (firebaseUser == null) {
      setState(() => _errorMessage = 'Auth session is not ready.');
      return;
    }

    setState(() {
      _isClearingLock = true;
      _errorMessage = null;
    });

    try {
      await clearOnboardingLock(
        functions: ref.read(firebaseFunctionsProvider),
        uid: firebaseUser.uid,
      );

      ref.invalidate(resolvedAuthSessionStreamProvider);
      ref.invalidate(bootstrapControllerProvider);

      if (!mounted) {
        return;
      }

      context.go('/bootstrap');
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(
        () => _errorMessage = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isClearingLock = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bootstrapControllerProvider);
    final theme = Theme.of(context);
    final email =
        state.session?.authUser.email ??
        ref.read(firebaseAuthProvider).currentUser?.email ??
        '';

    return Scaffold(
      body: AppBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 720
                  ? 48.0
                  : 24.0;
              final contentHeight = constraints.maxHeight - 24;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      12,
                      horizontalPadding,
                      12,
                    ),
                    child: Form(
                      key: _formKey,
                      child: SizedBox(
                        height: contentHeight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Clubs',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Create gym',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              email.isEmpty
                                  ? 'Set up your gym to continue.'
                                  : email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'First name',
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Required';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Last name',
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Required';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                              ),
                              onChanged: (value) {
                                final formatted = _formatPhone(value);
                                if (formatted != value) {
                                  _phoneController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                      offset: formatted.length,
                                    ),
                                  );
                                }
                              },
                              validator: (value) {
                                if ((value ?? '').trim().length < 17) {
                                  return 'Enter a full phone number.';
                                }

                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _clubNameController,
                                    textInputAction: TextInputAction.next,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Gym name',
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'Gym name is required.';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cityController,
                                    textInputAction: TextInputAction.done,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: const InputDecoration(
                                      labelText: 'City',
                                    ),
                                    validator: (value) {
                                      if ((value ?? '').trim().isEmpty) {
                                        return 'City is required.';
                                      }

                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                _errorMessage!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _isSubmitting || _isClearingLock
                                    ? null
                                    : _clearLockAndRetry,
                                child: Text(
                                  _isClearingLock
                                      ? 'Clearing onboarding lock...'
                                      : 'Clear onboarding lock',
                                ),
                              ),
                            ],
                            const Spacer(),
                            FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: Text(
                                _isSubmitting
                                    ? 'Creating gym...'
                                    : 'Create gym',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
