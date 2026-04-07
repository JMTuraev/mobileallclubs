import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_bootstrap_resolver.dart';
import '../../../core/services/firebase_bootstrap.dart';
import 'bootstrap_state.dart';

final bootstrapControllerProvider = Provider<BootstrapState>((ref) {
  final bootstrapResult = ref.watch(firebaseBootstrapResultProvider);

  if (!bootstrapResult.isInitialized) {
    return BootstrapState.bootstrapError(bootstrapResult.message);
  }

  final resolvedSession = ref.watch(resolvedAuthSessionStreamProvider);

  return resolvedSession.when(
    loading: BootstrapState.loading,
    error: (error, stackTrace) =>
        BootstrapState.bootstrapError(error.toString()),
    data: (session) {
      if (session == null) {
        return const BootstrapState.unauthenticated();
      }

      if (session.needsOnboarding) {
        return BootstrapState.onboardingRequired(session);
      }

      if (!session.authUser.emailVerified) {
        return BootstrapState.emailVerificationRequired(session);
      }

      return BootstrapState.authenticated(session);
    },
  );
});
