import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobileallclubs/features/auth/application/gym_profile_providers.dart';
import 'package:mobileallclubs/features/auth/presentation/profile_screen.dart';
import 'package:mobileallclubs/features/bootstrap/application/bootstrap_controller.dart';
import 'package:mobileallclubs/features/bootstrap/application/bootstrap_state.dart';
import 'package:mobileallclubs/models/auth_bootstrap_models.dart';

const _billingBlockedSession = ResolvedAuthSession(
  authUser: AuthenticatedUserSnapshot(
    uid: 'staff-123',
    email: 'staff@allclubs.test',
    displayName: 'Staff User',
    phoneNumber: null,
    isAnonymous: false,
    emailVerified: true,
  ),
  userProfile: GlobalUserProfile(
    uid: 'staff-123',
    email: 'staff@allclubs.test',
    gymId: 'gym-1',
    roleValue: 'staff',
  ),
  gymMembership: GymMembershipProfile(
    gymId: 'gym-1',
    uid: 'staff-123',
    email: 'staff@allclubs.test',
    roleValue: 'staff',
  ),
  gym: GymProfile(
    gymId: 'gym-1',
    name: 'AllClubs Gym',
    billingStatus: 'inactive',
    billingProvider: 'Lemon Squeezy',
    billingPlanName: 'AllClubs subscription',
    billingPortalUrl: 'https://allclubs.lemonsqueezy.com/billing',
    billingDashboardUrl: 'https://app.lemonsqueezy.com/',
    billingCustomerEmail: 'owner@example.com',
    readOnlyReason: 'Gym is in read-only mode until billing is active.',
    isReadOnly: true,
  ),
);

void main() {
  testWidgets('shows billing status details on the profile subscription page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_billingBlockedSession),
          ),
          currentGymProfileStreamProvider.overrideWith(
            (ref) => Stream.value(_billingBlockedSession.gym),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ProfileScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Subscription'));
    await tester.pumpAndSettle();

    expect(find.text('Billing access status'), findsOneWidget);
    expect(find.text('Status: inactive'), findsOneWidget);
    expect(
      find.text('Gym is in read-only mode until billing is active.'),
      findsOneWidget,
    );
    expect(find.text('AllClubs subscription'), findsOneWidget);
    expect(find.text('Lemon Squeezy'), findsOneWidget);
    expect(find.text('Manage billing'), findsOneWidget);
    expect(find.text('Billing activity'), findsOneWidget);
  });
}
