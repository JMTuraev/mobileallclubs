import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobileallclubs/core/services/auth_bootstrap_resolver.dart';
import 'package:mobileallclubs/core/services/firebase_bootstrap.dart';
import 'package:mobileallclubs/features/bootstrap/application/bootstrap_controller.dart';
import 'package:mobileallclubs/features/bootstrap/application/bootstrap_state.dart';
import 'package:mobileallclubs/models/auth_bootstrap_models.dart';

const _verifiedSession = ResolvedAuthSession(
  authUser: AuthenticatedUserSnapshot(
    uid: 'uid-001',
    email: 'owner@allclubs.test',
    displayName: 'Owner',
    phoneNumber: null,
    isAnonymous: false,
    emailVerified: true,
  ),
  userProfile: GlobalUserProfile(
    uid: 'uid-001',
    email: 'owner@allclubs.test',
    gymId: 'gym-1',
    roleValue: 'owner',
  ),
  gymMembership: GymMembershipProfile(
    gymId: 'gym-1',
    uid: 'uid-001',
    email: 'owner@allclubs.test',
    roleValue: 'owner',
  ),
  gym: GymProfile(gymId: 'gym-1', name: 'AllClubs Gym', ownerId: 'uid-001'),
);

const _unverifiedSession = ResolvedAuthSession(
  authUser: AuthenticatedUserSnapshot(
    uid: 'uid-001',
    email: 'owner@allclubs.test',
    displayName: 'Owner',
    phoneNumber: null,
    isAnonymous: false,
    emailVerified: false,
  ),
  userProfile: GlobalUserProfile(
    uid: 'uid-001',
    email: 'owner@allclubs.test',
    gymId: 'gym-1',
    roleValue: 'owner',
  ),
  gymMembership: GymMembershipProfile(
    gymId: 'gym-1',
    uid: 'uid-001',
    email: 'owner@allclubs.test',
    roleValue: 'owner',
  ),
  gym: GymProfile(gymId: 'gym-1', name: 'AllClubs Gym', ownerId: 'uid-001'),
);

const _onboardingSession = ResolvedAuthSession(
  authUser: AuthenticatedUserSnapshot(
    uid: 'uid-002',
    email: 'new@allclubs.test',
    displayName: 'New User',
    phoneNumber: null,
    isAnonymous: false,
    emailVerified: false,
  ),
);

const _superAdminSession = ResolvedAuthSession(
  authUser: AuthenticatedUserSnapshot(
    uid: 'uid-999',
    email: 'jafaralituraev@gmail.com',
    displayName: 'Platform Admin',
    phoneNumber: null,
    isAnonymous: false,
    emailVerified: true,
  ),
  userProfile: GlobalUserProfile(
    uid: 'uid-999',
    email: 'jafaralituraev@gmail.com',
    roleValue: 'super_admin',
    isActive: true,
  ),
);

void main() {
  test(
    'unauthenticated bootstrap enables the real email/password login flow',
    () async {
      final container = ProviderContainer(
        overrides: [
          firebaseBootstrapResultProvider.overrideWith(
            (ref) => const FirebaseBootstrapResult.initialized(),
          ),
          resolvedAuthSessionStreamProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        bootstrapControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );

      expect(subscription.read().stage, BootstrapStage.loading);

      await container.pump();

      final state = subscription.read();

      expect(state.stage, BootstrapStage.unauthenticated);
      expect(state.interactiveLoginEnabled, isTrue);
      expect(
        state.loginMessage,
        'Firebase email/password via signInWithEmailAndPassword.',
      );
      expect(state.userProfileResolutionEnabled, isTrue);
      expect(state.gymResolutionEnabled, isTrue);
      expect(state.roleResolutionEnabled, isTrue);
    },
  );

  test(
    'unverified accounts route to email verification after bootstrap',
    () async {
      final container = ProviderContainer(
        overrides: [
          firebaseBootstrapResultProvider.overrideWith(
            (ref) => const FirebaseBootstrapResult.initialized(),
          ),
          resolvedAuthSessionStreamProvider.overrideWith(
            (ref) => Stream.value(_unverifiedSession),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        bootstrapControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );

      await container.pump();

      final state = subscription.read();

      expect(state.stage, BootstrapStage.emailVerificationRequired);
      expect(state.session?.authUser.emailVerified, isFalse);
      expect(state.session?.userProfile?.docPath, 'users/uid-001');
    },
  );

  test('users without a resolved profile are routed into onboarding', () async {
    final container = ProviderContainer(
      overrides: [
        firebaseBootstrapResultProvider.overrideWith(
          (ref) => const FirebaseBootstrapResult.initialized(),
        ),
        resolvedAuthSessionStreamProvider.overrideWith(
          (ref) => Stream.value(_onboardingSession),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      bootstrapControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );

    await container.pump();

    final state = subscription.read();

    expect(state.stage, BootstrapStage.onboardingRequired);
    expect(state.session?.expectedUserDocPath, 'users/uid-002');
    expect(state.session?.userProfile, isNull);
  });

  test('authenticated bootstrap exposes the resolved tenant context', () async {
    final container = ProviderContainer(
      overrides: [
        firebaseBootstrapResultProvider.overrideWith(
          (ref) => const FirebaseBootstrapResult.initialized(),
        ),
        resolvedAuthSessionStreamProvider.overrideWith(
          (ref) => Stream.value(_verifiedSession),
        ),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      bootstrapControllerProvider,
      (previous, next) {},
      fireImmediately: true,
    );

    await container.pump();

    final state = subscription.read();

    expect(state.stage, BootstrapStage.authenticated);
    expect(state.session?.authUser.uid, 'uid-001');
    expect(state.session?.userProfile?.gymId, 'gym-1');
    expect(state.session?.gymMembership?.docPath, 'gyms/gym-1/users/uid-001');
    expect(state.session?.gym?.docPath, 'gyms/gym-1');
  });

  test(
    'super admin bootstrap skips gym resolution and remains authenticated',
    () async {
      final container = ProviderContainer(
        overrides: [
          firebaseBootstrapResultProvider.overrideWith(
            (ref) => const FirebaseBootstrapResult.initialized(),
          ),
          resolvedAuthSessionStreamProvider.overrideWith(
            (ref) => Stream.value(_superAdminSession),
          ),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        bootstrapControllerProvider,
        (previous, next) {},
        fireImmediately: true,
      );

      await container.pump();

      final state = subscription.read();

      expect(state.stage, BootstrapStage.authenticated);
      expect(state.session?.isSuperAdmin, isTrue);
      expect(state.session?.gymId, isNull);
      expect(state.session?.needsOnboarding, isFalse);
    },
  );
}
