import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mobileallclubs/app/app.dart';
import 'package:mobileallclubs/core/routing/app_router.dart';
import 'package:mobileallclubs/core/theme/app_theme.dart';
import 'package:mobileallclubs/core/widgets/app_shell_scaffold.dart';
import 'package:mobileallclubs/features/bootstrap/application/bootstrap_controller.dart';
import 'package:mobileallclubs/features/bootstrap/application/bootstrap_state.dart';
import 'package:mobileallclubs/features/auth/presentation/authenticated_shell_screen.dart';
import 'package:mobileallclubs/features/bar/application/bar_actions_service.dart';
import 'package:mobileallclubs/features/bar/application/bar_providers.dart';
import 'package:mobileallclubs/features/bar/domain/bar_category_summary.dart';
import 'package:mobileallclubs/features/bar/domain/bar_check_item.dart';
import 'package:mobileallclubs/features/bar/domain/bar_incoming_invoice_summary.dart';
import 'package:mobileallclubs/features/bar/domain/bar_product_summary.dart';
import 'package:mobileallclubs/features/bar/domain/bar_session_check_summary.dart';
import 'package:mobileallclubs/features/bar/presentation/bar_admin_screen.dart';
import 'package:mobileallclubs/features/bar/presentation/bar_menu_screen.dart';
import 'package:mobileallclubs/features/bar/presentation/bar_pos_screen.dart';
import 'package:mobileallclubs/features/clients/application/client_detail_providers.dart';
import 'package:mobileallclubs/features/clients/application/client_insights_providers.dart';
import 'package:mobileallclubs/features/clients/application/clients_providers.dart';
import 'package:mobileallclubs/features/clients/domain/client_detail_models.dart';
import 'package:mobileallclubs/features/clients/domain/client_insights_summary.dart';
import 'package:mobileallclubs/features/clients/domain/client_summary.dart';
import 'package:mobileallclubs/features/clients/presentation/client_insights_card.dart';
import 'package:mobileallclubs/features/clients/presentation/client_detail_screen.dart';
import 'package:mobileallclubs/features/clients/presentation/clients_screen.dart';
import 'package:mobileallclubs/features/clients/presentation/create_client_screen.dart';
import 'package:mobileallclubs/features/dashboard/application/dashboard_providers.dart';
import 'package:mobileallclubs/features/dashboard/domain/owner_analytics_models.dart';
import 'package:mobileallclubs/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobileallclubs/features/finance/application/transaction_providers.dart';
import 'package:mobileallclubs/features/finance/domain/gym_transaction_summary.dart';
import 'package:mobileallclubs/features/invites/application/invite_providers.dart';
import 'package:mobileallclubs/features/invites/domain/gym_invite_summary.dart';
import 'package:mobileallclubs/features/invites/presentation/accept_invite_screen.dart';
import 'package:mobileallclubs/features/invites/presentation/invites_screen.dart';
import 'package:mobileallclubs/features/packages/application/package_providers.dart';
import 'package:mobileallclubs/features/packages/domain/gym_package_summary.dart';
import 'package:mobileallclubs/features/packages/presentation/packages_screen.dart';
import 'package:mobileallclubs/features/sessions/application/sessions_providers.dart';
import 'package:mobileallclubs/features/sessions/domain/gym_session_summary.dart';
import 'package:mobileallclubs/features/sessions/presentation/sessions_screen.dart';
import 'package:mobileallclubs/features/staff/application/staff_providers.dart';
import 'package:mobileallclubs/features/staff/domain/gym_staff_summary.dart';
import 'package:mobileallclubs/features/staff/presentation/create_staff_screen.dart';
import 'package:mobileallclubs/features/staff/presentation/staff_screen.dart';
import 'package:mobileallclubs/models/auth_bootstrap_models.dart';

const _verifiedSession = ResolvedAuthSession(
  authUser: AuthenticatedUserSnapshot(
    uid: 'user-123',
    email: 'owner@allclubs.test',
    displayName: 'Owner User',
    phoneNumber: null,
    isAnonymous: false,
    emailVerified: true,
  ),
  userProfile: GlobalUserProfile(
    uid: 'user-123',
    email: 'owner@allclubs.test',
    gymId: 'gym-1',
    roleValue: 'owner',
  ),
  gymMembership: GymMembershipProfile(
    gymId: 'gym-1',
    uid: 'user-123',
    email: 'owner@allclubs.test',
    roleValue: 'owner',
  ),
  gym: GymProfile(
    gymId: 'gym-1',
    name: 'AllClubs Gym',
    city: 'Tashkent',
    ownerId: 'user-123',
  ),
);

const _staffSession = ResolvedAuthSession(
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
    city: 'Tashkent',
    ownerId: 'user-123',
  ),
);

const _unverifiedSession = ResolvedAuthSession(
  authUser: AuthenticatedUserSnapshot(
    uid: 'user-123',
    email: 'owner@allclubs.test',
    displayName: 'Owner User',
    phoneNumber: null,
    isAnonymous: false,
    emailVerified: false,
  ),
  userProfile: GlobalUserProfile(
    uid: 'user-123',
    email: 'owner@allclubs.test',
    gymId: 'gym-1',
    roleValue: 'owner',
  ),
  gymMembership: GymMembershipProfile(
    gymId: 'gym-1',
    uid: 'user-123',
    email: 'owner@allclubs.test',
    roleValue: 'owner',
  ),
  gym: GymProfile(
    gymId: 'gym-1',
    name: 'AllClubs Gym',
    city: 'Tashkent',
    ownerId: 'user-123',
  ),
);

const _onboardingSession = ResolvedAuthSession(
  authUser: AuthenticatedUserSnapshot(
    uid: 'new-user-1',
    email: 'new@allclubs.test',
    displayName: 'New User',
    phoneNumber: null,
    isAnonymous: false,
    emailVerified: false,
  ),
);

const _sampleClients = [
  GymClientSummary(
    id: 'client-001',
    firstName: 'Ali',
    lastName: 'Valiyev',
    phone: '+998 90 123 45 67',
    email: 'ali@example.com',
    cardId: 'CARD-1',
  ),
  GymClientSummary(
    id: 'client-002',
    firstName: 'Laylo',
    lastName: 'Karimova',
    phone: '+998 91 765 43 21',
    email: 'laylo@example.com',
  ),
];

final _sampleClientDetail = GymClientDetail(
  id: 'client-001',
  firstName: 'Ali',
  lastName: 'Valiyev',
  phone: '+998 90 123 45 67',
  email: 'ali@example.com',
  cardId: 'CARD-1',
  gender: 'male',
  age: 28,
  type: 'member',
  lifetimeSpent: 1500000,
  createdAt: DateTime(2026, 3, 2, 14, 30),
);

final _samplePackages = [
  GymPackageSummary(
    id: 'package-001',
    name: 'Premium 12',
    price: 900000,
    duration: 30,
    visitLimit: 12,
    isUnlimited: false,
    freezeEnabled: true,
    maxFreezeDays: 7,
    createdAt: DateTime(2026, 4, 1, 8, 0),
  ),
];

final _sampleSubscriptions = [
  ClientSubscriptionSummary(
    id: 'subscription-001',
    clientId: 'client-001',
    clientName: 'Ali Valiyev',
    clientPhone: '+998 90 123 45 67',
    packageId: 'package-001',
    status: 'active',
    sessionsCount: 0,
    packageName: 'Premium 12',
    packagePrice: 900000,
    packageDurationDays: 30,
    isUnlimited: false,
    visitLimit: 12,
    remainingVisits: 7,
    startDate: DateTime(2026, 4, 1, 9, 0),
    endDate: DateTime(2026, 5, 1, 9, 0),
    createdAt: DateTime(2026, 4, 1, 9, 0),
  ),
];

final _sampleSessions = [
  ClientSessionSummary(
    id: 'session-001',
    clientId: 'client-001',
    subscriptionId: 'subscription-001',
    status: 'active',
    locker: '24',
    createdAt: DateTime(2026, 4, 5, 10, 0),
    startedAt: DateTime(2026, 4, 5, 10, 5),
  ),
  ClientSessionSummary(
    id: 'session-000',
    clientId: 'client-001',
    subscriptionId: 'subscription-001',
    status: 'completed',
    createdAt: DateTime(2026, 4, 4, 9, 0),
    startedAt: DateTime(2026, 4, 4, 9, 5),
    endedAt: DateTime(2026, 4, 4, 10, 2),
  ),
];

final _sampleGymSessions = [
  GymSessionSummary(
    id: 'gym-session-001',
    clientId: 'client-001',
    clientName: 'Ali Valiyev',
    packageName: 'Premium 12',
    locker: '24',
    status: 'active',
    staffName: 'Coach Bot',
    createdAt: DateTime(2026, 4, 5, 10, 0),
    startedAt: DateTime(2026, 4, 5, 10, 5),
  ),
  GymSessionSummary(
    id: 'gym-session-002',
    clientId: 'client-002',
    clientName: 'Laylo Karimova',
    packageName: 'Morning',
    locker: '17',
    status: 'completed',
    staffName: 'Front Desk',
    createdAt: DateTime(2026, 4, 4, 9, 0),
    startedAt: DateTime(2026, 4, 4, 9, 5),
    endedAt: DateTime(2026, 4, 4, 10, 2),
  ),
];

final _sampleTransactions = [
  GymTransactionSummary(
    id: 'tx-001',
    clientId: 'client-001',
    subscriptionId: 'subscription-001',
    subscriptionStatus: 'active',
    type: 'payment',
    category: 'package',
    paymentMethod: 'cash',
    amount: 500000,
    createdAt: DateTime(2026, 4, 1, 11, 0),
  ),
  GymTransactionSummary(
    id: 'tx-002',
    clientId: 'client-001',
    subscriptionId: 'subscription-001',
    subscriptionStatus: 'active',
    type: 'payment',
    category: 'package',
    paymentMethod: 'card',
    amount: 400000,
    createdAt: DateTime(2026, 4, 2, 11, 0),
  ),
];

final _sampleClientInsights = ClientInsightsSummary(
  id: 'client-001',
  clientId: 'client-001',
  attendanceDirection: 'up',
  attendanceDelta: 3,
  last30Visits: 11,
  previous30Visits: 8,
  visitsPerWeek: 2.5,
  inactiveDays: 4,
  churnRisk: 'medium',
  lifetimeValue: 1500000,
  lastVisitAt: DateTime(2026, 4, 4, 10, 2),
  alerts: [
    ClientInsightAlert(
      type: 'retention',
      title: 'Follow up soon',
      description: 'Attendance softened this week.',
      severity: 'medium',
    ),
  ],
);

const _sampleOwnerAnalytics = OwnerAnalyticsSeries(
  days: [
    OwnerAnalyticsDay(
      date: '2026-03-31',
      totalSessions: 42,
      activeClients: 27,
      newClients: 3,
      revenue: 4200000,
      gyms: [
        OwnedGymDailySummary(
          gymId: 'gym-1',
          gymName: 'AllClubs Gym',
          totalSessions: 42,
          activeClients: 27,
          newClients: 3,
          revenue: 4200000,
          peakHours: [PeakHourSummary(hour: '18:00', sessionsCount: 12)],
        ),
      ],
    ),
    OwnerAnalyticsDay(
      date: '2026-04-01',
      totalSessions: 47,
      activeClients: 30,
      newClients: 4,
      revenue: 4900000,
      gyms: [
        OwnedGymDailySummary(
          gymId: 'gym-1',
          gymName: 'AllClubs Gym',
          totalSessions: 47,
          activeClients: 30,
          newClients: 4,
          revenue: 4900000,
          peakHours: [PeakHourSummary(hour: '19:00', sessionsCount: 14)],
        ),
      ],
    ),
  ],
);

const _sampleDailyStats = GymDailyStatsSnapshot(
  id: '2026-04-01',
  date: '2026-04-01',
  totalSessions: 47,
  activeClients: 30,
  newClients: 4,
  revenue: 4900000,
);

const _sampleStaff = [
  GymStaffSummary(
    id: 'staff-001',
    fullName: 'Coach Bot',
    phone: '+998 90 000 00 01',
    roleValue: 'staff',
    isActive: true,
  ),
  GymStaffSummary(
    id: 'staff-002',
    fullName: 'Front Desk',
    phone: '+998 90 000 00 02',
    roleValue: 'staff',
    isActive: false,
  ),
];

const _sampleInvites = [
  GymInviteSummary(
    id: 'invite-001',
    email: 'coach@allclubs.test',
    roleValue: 'staff',
    status: 'pending',
    gymId: 'gym-1',
    token: 'token-001',
    staffData: InviteStaffData(
      fullName: 'Coach Invite',
      phone: '+998 90 777 77 77',
    ),
  ),
  GymInviteSummary(
    id: 'invite-002',
    email: 'frontdesk@allclubs.test',
    roleValue: 'staff',
    status: 'accepted',
    gymId: 'gym-1',
    staffData: InviteStaffData(
      fullName: 'Front Desk Invite',
      phone: '+998 90 888 88 88',
    ),
  ),
];

const _sampleBarCategories = [
  BarCategorySummary(id: 'bar-cat-1', name: 'Coffee', isActive: true),
  BarCategorySummary(id: 'bar-cat-2', name: 'Snacks', isActive: true),
];

const _sampleBarProducts = [
  BarProductSummary(
    id: 'bar-product-1',
    name: 'Americano',
    categoryId: 'bar-cat-1',
    price: 18000,
    stock: 8,
    isActive: true,
  ),
  BarProductSummary(
    id: 'bar-product-2',
    name: 'Protein Bar',
    categoryId: 'bar-cat-2',
    price: 25000,
    stock: 12,
    isActive: true,
  ),
];

const _sampleBarCheckItems = [
  BarCheckItem(
    id: 'bar-item-1',
    checkId: 'bar-check-1',
    productId: 'bar-product-1',
    name: 'Americano',
    price: 18000,
    qty: 2,
    subtotal: 36000,
  ),
];

final _sampleBarSessionChecks = [
  BarSessionCheckSummary(
    id: 'bar-check-1',
    status: 'paid',
    totalAmount: 36000,
    paidAmount: 36000,
    debtAmount: 0,
    itemCount: 2,
    createdAt: DateTime(2026, 4, 7, 12, 20),
  ),
];

final _sampleIncomingInvoices = [
  BarIncomingInvoiceSummary(
    id: 'incoming-1',
    invoiceNumber: 'INV-001',
    items: const [
      BarIncomingInvoiceItem(
        productId: 'bar-product-1',
        name: 'Americano',
        quantity: 4,
        purchasePrice: 10000,
      ),
    ],
    total: 40000,
    createdAt: DateTime(2026, 4, 7, 12, 0),
  ),
];

class _FakeBarActionsService implements BarActionsService {
  const _FakeBarActionsService({this.draftCheckId});

  final String? draftCheckId;
  static const _emptyDebtSnapshot = BarClientDebtSnapshot(
    totalDebt: 0,
    unpaidChecks: <BarDebtCheckSnapshot>[],
  );

  @override
  String? get gymId => 'gym-1';

  @override
  Future<void> addItemToCheck({
    required String checkId,
    required String productId,
    int qty = 1,
  }) async {}

  @override
  Future<BarClientDebtSnapshot> checkClientDebt({
    required String clientId,
  }) async => _emptyDebtSnapshot;

  @override
  Future<void> createCategory({
    required BarCategoryUpsertRequest request,
  }) async {}

  @override
  Future<void> createIncoming({
    required List<BarIncomingItemRequest> items,
  }) async {}

  @override
  Future<void> createProduct({
    required BarProductCreateRequest request,
  }) async {}

  @override
  Future<void> deleteCategory({required String categoryId}) async {}

  @override
  Future<void> deleteIncoming({required String incomingId}) async {}

  @override
  Future<void> deleteProduct({required String productId}) async {}

  @override
  Future<String?> findDraftCheckId({required String sessionId}) async =>
      draftCheckId;

  @override
  Future<String?> getOrCreateOpenCheck({
    String? clientId,
    String? sessionId,
  }) async => draftCheckId ?? 'bar-check-1';

  @override
  Future<void> holdCheck({required String checkId}) async {}

  @override
  Future<void> payCheck({
    required String checkId,
    required Map<String, num> methods,
  }) async {}

  @override
  Future<void> refundCheck({required String checkId}) async {}

  @override
  Future<void> removeItemFromCheck({
    required String checkId,
    required String productId,
    int qty = 1,
  }) async {}

  @override
  Future<void> updateCategory({
    required String categoryId,
    required BarCategoryUpsertRequest request,
  }) async {}

  @override
  Future<void> updateProduct({
    required String productId,
    required BarProductUpdateRequest request,
  }) async {}

  @override
  Future<String> uploadProductImage({
    required Uint8List bytes,
    required String fileName,
  }) async => 'https://example.com/$fileName';

  @override
  Future<void> voidCheck({required String checkId}) async {}
}

Widget _buildScreenHarness({required List overrides, required Widget child}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void main() {
  testWidgets(
    'shows the bootstrap loading screen while session state resolves',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bootstrapControllerProvider.overrideWith(
              (ref) => const BootstrapState.loading(),
            ),
          ],
          child: const AllClubsMobileApp(),
        ),
      );
      await tester.pump();

      expect(find.text('Preparing secure session'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    },
  );

  testWidgets('does not expose placeholder module navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.unauthenticated(),
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Asosiy'), findsNothing);
    expect(find.text('Mijozlar'), findsNothing);
    expect(find.text('Sessiyalar'), findsNothing);
    expect(find.text('Yana'), findsNothing);
  });

  testWidgets('shows the real email and password login flow when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.unauthenticated(),
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(
      find.text('Firebase email/password via signInWithEmailAndPassword.'),
      findsOneWidget,
    );
  });

  testWidgets('opens the forgot-password route from the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.unauthenticated(),
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Send reset link'), findsOneWidget);
    expect(find.text('Back to sign in'), findsOneWidget);
  });

  testWidgets('opens the register route from the login screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.unauthenticated(),
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Create account'), findsWidgets);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
  });

  testWidgets('shows the verify-email screen for unverified accounts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.emailVerificationRequired(
              _unverifiedSession,
            ),
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify email'), findsOneWidget);
    expect(find.text('Send verification email again'), findsOneWidget);
    expect(find.text('I verified my email'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('routes onboarding users to the create-gym screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) =>
                const BootstrapState.onboardingRequired(_onboardingSession),
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create gym'), findsWidgets);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Gym name'), findsOneWidget);
    expect(find.text('Confirm email'), findsOneWidget);
  });

  testWidgets('shows the authenticated shell when a session is restored', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
        ],
        child: const AuthenticatedShellScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthenticatedShellScreen), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('owner@allclubs.test'), findsOneWidget);
  });

  testWidgets('opens the real clients module from the authenticated shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymClientsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleClients),
          ),
        ],
        child: const ClientsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClientsScreen), findsOneWidget);
    expect(find.text('AllClubs Gym'), findsOneWidget);
  });

  testWidgets('opens the real sessions module from the authenticated shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymSessionsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleGymSessions),
          ),
        ],
        child: const SessionsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SessionsScreen), findsOneWidget);
    expect(find.text('AllClubs Gym'), findsOneWidget);
  });

  testWidgets('renders filtered client sessions inside the shared shell body', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymSessionsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleGymSessions),
          ),
          currentGymClientDocumentProvider(
            'client-001',
          ).overrideWith((ref) => Stream.value(_sampleClientDetail)),
        ],
        child: const SessionsScreen(clientId: 'client-001'),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Client sessions'), findsOneWidget);
    expect(find.text('Back to client'), findsOneWidget);
    expect(find.text('Client filter'), findsOneWidget);
    expect(find.text('Ali Valiyev'), findsWidgets);
    expect(find.text('1 sessions'), findsOneWidget);
  });

  testWidgets('renders sold package rows with edit and replace actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymPackagesProvider.overrideWith(
            (ref) => Stream.value(_samplePackages),
          ),
          currentGymSubscriptionsProvider.overrideWith(
            (ref) => Stream.value(_sampleSubscriptions),
          ),
          currentGymClientsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleClients),
          ),
        ],
        child: const PackagesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Templates'), findsOneWidget);
    expect(find.text('Sold packages'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Sold packages'));
    await tester.pumpAndSettle();

    expect(find.text('Ali Valiyev', skipOffstage: false), findsOneWidget);
    expect(find.text('Premium 12', skipOffstage: false), findsOneWidget);
    expect(find.text('Edit', skipOffstage: false), findsOneWidget);
    expect(find.text('Replace', skipOffstage: false), findsOneWidget);
  });

  testWidgets('keeps the shared shell visible across main tab changes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymClientsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleClients),
          ),
          currentGymSessionsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleGymSessions),
          ),
          currentGymTransactionsProvider.overrideWith(
            (ref) => Stream.value(_sampleTransactions),
          ),
          currentGymSubscriptionsProvider.overrideWith(
            (ref) => Stream.value(_sampleSubscriptions),
          ),
          ownerAnalytics30DayProvider.overrideWith(
            (ref) async => _sampleOwnerAnalytics,
          ),
          currentGymDailyStatsProvider.overrideWith(
            (ref) async => _sampleDailyStats,
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppShellScaffold), findsOneWidget);
    expect(find.text('Clients'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Packages'), findsOneWidget);
    expect(find.byTooltip('POS'), findsOneWidget);
    expect(find.byTooltip('Stats'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);

    await tester.tap(find.byTooltip('POS'));
    await tester.pumpAndSettle();
    expect(find.byType(BarMenuScreen), findsOneWidget);
    expect(find.text('POS Menu'), findsOneWidget);
    expect(find.text('Open guest POS'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ali Valiyev'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(find.text('Open POS'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to app'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShellScaffold), findsOneWidget);

    await tester.tap(find.byTooltip('Stats'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Today gym stats'), findsOneWidget);
    expect(find.text('Owner analytics'), findsOneWidget);
    expect(find.text('2026-04-01'), findsWidgets);

    await tester.tap(find.byTooltip('Back to app'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShellScaffold), findsOneWidget);

    await tester.tap(find.text('Clients'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShellScaffold), findsOneWidget);
    expect(find.byType(ClientsScreen), findsOneWidget);

    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShellScaffold), findsOneWidget);
    expect(find.byType(SessionsScreen), findsOneWidget);

    await tester.tap(find.text('Finance'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShellScaffold), findsOneWidget);
    expect(find.text('Finance'), findsWidgets);

    await tester.tap(find.text('Packages'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShellScaffold), findsOneWidget);
    expect(find.text('Packages'), findsWidgets);

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShellScaffold), findsOneWidget);
    expect(find.byType(AuthenticatedShellScreen), findsOneWidget);
  });

  testWidgets('shows current gym daily stats for staff sessions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_staffSession),
          ),
          currentGymDailyStatsProvider.overrideWith(
            (ref) async => _sampleDailyStats,
          ),
        ],
        child: const DashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Today gym stats'), findsOneWidget);
    expect(find.text('2026-04-01'), findsOneWidget);
    expect(find.text('Owner analytics unavailable'), findsOneWidget);
  });

  testWidgets('hides the shared bottom dock while the keyboard is visible', (
    WidgetTester tester,
  ) async {
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymClientsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleClients),
          ),
          currentGymSessionsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleGymSessions),
          ),
          currentGymTransactionsProvider.overrideWith(
            (ref) => Stream.value(_sampleTransactions),
          ),
          currentGymSubscriptionsProvider.overrideWith(
            (ref) => Stream.value(_sampleSubscriptions),
          ),
          ownerAnalytics30DayProvider.overrideWith(
            (ref) async => _sampleOwnerAnalytics,
          ),
          currentGymDailyStatsProvider.overrideWith(
            (ref) async => _sampleDailyStats,
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Clients'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Packages'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pumpAndSettle();

    expect(find.text('Clients'), findsNothing);
    expect(find.text('Sessions'), findsNothing);
    expect(find.text('Finance'), findsNothing);
    expect(find.text('Packages'), findsNothing);
    expect(find.byTooltip('POS'), findsOneWidget);
    expect(find.byTooltip('Stats'), findsOneWidget);
    expect(find.byTooltip('Profile'), findsOneWidget);
  });

  testWidgets('renders the owner-only bar admin categories content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymBarCategoriesProvider.overrideWith(
            (ref) => Stream.value(_sampleBarCategories),
          ),
          currentGymBarProductsProvider.overrideWith(
            (ref) => Stream.value(_sampleBarProducts),
          ),
          currentGymBarIncomingProvider.overrideWith(
            (ref) => Stream.value(_sampleIncomingInvoices),
          ),
        ],
        child: const BarAdminScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Bar admin'), findsWidgets);
    expect(find.text('Categories'), findsWidgets);
    expect(find.text('Category name'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Snacks'), findsOneWidget);
  });

  testWidgets('renders the owner-only bar admin products content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymBarCategoriesProvider.overrideWith(
            (ref) => Stream.value(_sampleBarCategories),
          ),
          currentGymBarProductsProvider.overrideWith(
            (ref) => Stream.value(_sampleBarProducts),
          ),
          currentGymBarIncomingProvider.overrideWith(
            (ref) => Stream.value(_sampleIncomingInvoices),
          ),
        ],
        child: const BarAdminScreen(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Products'));
    await tester.pumpAndSettle();

    expect(find.text('Products'), findsWidgets);
    expect(find.text('New product'), findsOneWidget);
    expect(find.text('Americano'), findsOneWidget);
    expect(find.textContaining('Stock 8'), findsOneWidget);
  });

  testWidgets('renders the owner-only bar admin incoming content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymBarCategoriesProvider.overrideWith(
            (ref) => Stream.value(_sampleBarCategories),
          ),
          currentGymBarProductsProvider.overrideWith(
            (ref) => Stream.value(_sampleBarProducts),
          ),
          currentGymBarIncomingProvider.overrideWith(
            (ref) => Stream.value(_sampleIncomingInvoices),
          ),
        ],
        child: const BarAdminScreen(),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Incoming'));
    await tester.pumpAndSettle();

    expect(find.text('Create incoming invoice'), findsOneWidget);
    expect(find.text('Draft invoice'), findsOneWidget);
    expect(find.text('Incoming history'), findsOneWidget);
    expect(find.text('Americano'), findsWidgets);
    expect(find.text('INV-001'), findsOneWidget);
  });

  testWidgets('renders the bar POS client, products, cart, and history', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          barActionsServiceProvider.overrideWithValue(
            const _FakeBarActionsService(draftCheckId: 'bar-check-1'),
          ),
          currentGymClientDocumentProvider(
            'client-001',
          ).overrideWith((ref) => Stream.value(_sampleClientDetail)),
          currentGymBarCategoriesProvider.overrideWith(
            (ref) => Stream.value(_sampleBarCategories),
          ),
          currentGymBarProductsProvider.overrideWith(
            (ref) => Stream.value(_sampleBarProducts),
          ),
          barCheckItemsProvider(
            'bar-check-1',
          ).overrideWith((ref) => Stream.value(_sampleBarCheckItems)),
          barSessionChecksProvider(
            'session-001',
          ).overrideWith((ref) => Stream.value(_sampleBarSessionChecks)),
        ],
        child: const BarPosScreen(
          clientId: 'client-001',
          sessionId: 'session-001',
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Current session'), findsOneWidget);
    expect(find.text('Ali Valiyev'), findsOneWidget);
    expect(find.text('Draft check bar-check-1'), findsOneWidget);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.text('Coffee'), findsWidgets);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Americano'), findsWidgets);
    expect(find.text('Current check'), findsOneWidget);
    expect(find.text('36000 so\'m'), findsWidgets);
    expect(find.text('Check history'), findsOneWidget);
    expect(find.text('Refund paid check'), findsOneWidget);
    expect(find.text('Check debt'), findsOneWidget);
  });

  testWidgets('renders guest bar POS without debt or session history', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          barActionsServiceProvider.overrideWithValue(
            const _FakeBarActionsService(),
          ),
          currentGymBarCategoriesProvider.overrideWith(
            (ref) => Stream.value(_sampleBarCategories),
          ),
          currentGymBarProductsProvider.overrideWith(
            (ref) => Stream.value(_sampleBarProducts),
          ),
        ],
        child: const BarPosScreen(isGuestMode: true),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Guest POS'), findsWidgets);
    expect(
      find.textContaining('createCheck with null clientId and null sessionId'),
      findsOneWidget,
    );
    expect(find.text('Client debt'), findsNothing);
    expect(find.text('Check history'), findsNothing);
    expect(find.text('Americano'), findsWidgets);
  });

  testWidgets('opens the real owner-only staff module from the shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymStaffStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleStaff),
          ),
        ],
        child: const StaffScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff'), findsWidgets);
    expect(find.text('Coach Bot'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Front Desk'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Front Desk'), findsOneWidget);
    expect(find.text('+998 90 000 00 01'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
  });

  testWidgets('opens the create-staff route from the staff module', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.staff,
      routes: [
        GoRoute(
          path: AppRoutes.staff,
          builder: (context, state) => const StaffScreen(),
        ),
        GoRoute(
          path: AppRoutes.createStaff,
          builder: (context, state) => const CreateStaffScreen(),
        ),
      ],
      redirect: (context, state) => state.matchedLocation == AppRoutes.staff
          ? null
          : state.matchedLocation == AppRoutes.createStaff
          ? null
          : AppRoutes.staff,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymStaffStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleStaff),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff'), findsWidgets);
    await tester.tap(find.text('Create staff'));
    await tester.pumpAndSettle();

    expect(find.text('Create staff'), findsWidgets);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('opens the owner invite-management route from the staff module', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.staff,
      routes: [
        GoRoute(
          path: AppRoutes.staff,
          builder: (context, state) => const StaffScreen(),
        ),
        GoRoute(
          path: AppRoutes.staffInvites,
          builder: (context, state) => const InvitesScreen(),
        ),
      ],
      redirect: (context, state) => state.matchedLocation == AppRoutes.staff
          ? null
          : state.matchedLocation == AppRoutes.staffInvites
          ? null
          : AppRoutes.staff,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymStaffStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleStaff),
          ),
          gymInvitesProvider.overrideWith((ref) async => _sampleInvites),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff'), findsWidgets);
    await tester.tap(find.text('Manage invites'));
    await tester.pumpAndSettle();

    expect(find.text('Staff invites'), findsWidgets);
    expect(find.text('Send staff invite'), findsOneWidget);
    expect(find.text('Coach Invite'), findsOneWidget);
    expect(find.text('Resend'), findsWidgets);
  });

  testWidgets('opens the create-client route from the clients module', (
    WidgetTester tester,
  ) async {
    final router = GoRouter(
      initialLocation: AppRoutes.clients,
      routes: [
        GoRoute(
          path: AppRoutes.clients,
          builder: (context, state) => const ClientsScreen(),
        ),
        GoRoute(
          path: AppRoutes.createClient,
          builder: (context, state) => const CreateClientScreen(),
        ),
      ],
      redirect: (context, state) => state.matchedLocation == AppRoutes.clients
          ? null
          : state.matchedLocation == AppRoutes.createClient
          ? null
          : AppRoutes.clients,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          currentGymClientsStreamProvider.overrideWith(
            (ref) => Stream.value(_sampleClients),
          ),
          currentGymSubscriptionsProvider.overrideWith(
            (ref) => Stream.value(_sampleSubscriptions),
          ),
          currentGymSessionsProvider.overrideWith(
            (ref) => Stream.value(_sampleSessions),
          ),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New client'), findsOneWidget);
    await tester.tap(find.text('New client'));
    await tester.pumpAndSettle();

    expect(find.text('Create client'), findsWidgets);
    expect(find.text('First name'), findsOneWidget);
    expect(find.text('Last name'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Gender'), findsOneWidget);
  });

  testWidgets(
    'opens the real read-only client profile detail from the clients list',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildScreenHarness(
          overrides: [
            bootstrapControllerProvider.overrideWith(
              (ref) => const BootstrapState.authenticated(_verifiedSession),
            ),
            currentGymClientDocumentProvider(
              'client-001',
            ).overrideWith((ref) => Stream.value(_sampleClientDetail)),
            currentGymClientSubscriptionsProvider(
              'client-001',
            ).overrideWith((ref) => AsyncValue.data(_sampleSubscriptions)),
            currentGymClientSessionsProvider(
              'client-001',
            ).overrideWith((ref) => AsyncValue.data(_sampleSessions)),
            currentGymClientTransactionsProvider(
              'client-001',
            ).overrideWith((ref) => AsyncValue.data(_sampleTransactions)),
            clientInsightsProvider(
              'client-001',
            ).overrideWith((ref) async => _sampleClientInsights),
          ],
          child: const ClientDetailScreen(clientId: 'client-001'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Client profile'), findsOneWidget);
      expect(find.text('Client actions'), findsOneWidget);
      expect(find.text('Bind card'), findsOneWidget);
      expect(find.text('Give key'), findsOneWidget);
      expect(find.text('End session'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Profile'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('+998 90 123 45 67'), findsWidgets);
      expect(find.text('CARD-1'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Subscription summary'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Subscription summary'), findsOneWidget);
      expect(find.text('Premium 12'), findsOneWidget);
      expect(find.text('Edit start date'), findsOneWidget);
      expect(find.text('Deactivate'), findsOneWidget);
      expect(find.text('Cancel subscription'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Finance summary'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Finance summary'), findsOneWidget);
      expect(find.text('900000'), findsWidgets);
      expect(find.text('cash'), findsOneWidget);
      expect(find.text('card'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Session summary'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Session summary'), findsOneWidget);
      expect(find.text('Active now'), findsOneWidget);
      expect(find.text('Locker 24'), findsOneWidget);
    },
  );

  testWidgets('shows exact client insights callable data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.authenticated(_verifiedSession),
          ),
          clientInsightsProvider(
            'client-001',
          ).overrideWith((ref) async => _sampleClientInsights),
        ],
        child: const ClientInsightsCard(clientId: 'client-001'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Client insights'), findsOneWidget);
    expect(find.text('Last 30 visits'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('Previous 30'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Follow up soon'), findsOneWidget);
    expect(find.text('Attendance softened this week.'), findsOneWidget);
    expect(find.text('retention • medium'), findsOneWidget);
  });

  testWidgets('shows a safe missing-token state for accept-invite', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildScreenHarness(
        overrides: const [],
        child: const AcceptInviteScreen(token: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Invite link unavailable'), findsOneWidget);
    expect(find.text('Missing invite token.'), findsOneWidget);
    expect(find.text('Go to sign in'), findsOneWidget);
  });

  testWidgets('opens developer firebase diagnostics in debug mode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bootstrapControllerProvider.overrideWith(
            (ref) => const BootstrapState.unauthenticated(),
          ),
        ],
        child: const AllClubsMobileApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.text('Open Developer Firebase Diagnostics'),
    );
    await tester.tap(find.text('Open Developer Firebase Diagnostics'));
    await tester.pumpAndSettle();

    expect(find.text('Developer Firebase Diagnostics'), findsOneWidget);
    expect(find.text('Developer-only runtime verification'), findsOneWidget);
  });
}
