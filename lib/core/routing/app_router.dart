import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/authenticated_shell_screen.dart';
import '../../features/bar/presentation/bar_admin_screen.dart';
import '../../features/bar/presentation/bar_pos_screen.dart';
import '../../features/bar/presentation/bar_menu_screen.dart';
import '../../features/auth/presentation/create_gym_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/invites/presentation/accept_invite_screen.dart';
import '../../features/invites/presentation/invites_screen.dart';
import '../../features/bootstrap/application/bootstrap_controller.dart';
import '../../features/bootstrap/application/bootstrap_state.dart';
import '../../features/bootstrap/presentation/bootstrap_gate_screen.dart';
import '../../features/bootstrap/presentation/firebase_diagnostics_screen.dart';
import '../../features/clients/presentation/client_detail_screen.dart';
import '../../features/clients/presentation/create_client_screen.dart';
import '../../features/clients/presentation/clients_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/finance/presentation/collect_payment_screen.dart';
import '../../features/finance/presentation/finance_screen.dart';
import '../../features/packages/presentation/activate_package_screen.dart';
import '../../features/packages/presentation/create_package_screen.dart';
import '../../features/packages/domain/gym_package_summary.dart';
import '../../features/packages/presentation/packages_screen.dart';
import '../../features/sessions/presentation/sessions_screen.dart';
import '../../features/staff/presentation/create_staff_screen.dart';
import '../../features/staff/presentation/staff_screen.dart';
import '../widgets/app_shell_scaffold.dart';

abstract final class AppRoutes {
  static const root = '/';
  static const bootstrap = '/bootstrap';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';
  static const acceptInvite = '/accept-invite';
  static const createGym = '/auth/create-gym';
  static const verifyEmail = '/auth/verify-email';
  static const app = '/app';
  static const stats = '/app/stats';
  static const barMenu = '/app/bar/pos';
  static const barGuestPos = '/app/bar/pos/guest';
  static const barAdmin = '/app/bar/admin';
  static const clients = '/app/clients';
  static const createClient = '/app/clients/create';
  static const sessions = '/app/sessions';
  static const finance = '/app/finance';
  static const packages = '/app/packages';
  static const createPackage = '/app/packages/create';
  static const editPackage = '/app/packages/edit';
  static const packageSubscriptionAction = '/app/packages/subscription-action';
  static const staff = '/app/staffs';
  static const createStaff = '/app/staffs/create';
  static const staffInvites = '/app/staffs/invites';
  static String clientDetail(String clientId) => '$clients/$clientId';
  static String activatePackage(String clientId) =>
      '${clientDetail(clientId)}/activate-package';
  static String collectPayment(String clientId) =>
      '${clientDetail(clientId)}/collect-payment';
  static String barPos(String clientId, String sessionId) => Uri(
    path: '${clientDetail(clientId)}/bar',
    queryParameters: {'sessionId': sessionId},
  ).toString();
  static String sessionsForClient(String clientId) =>
      Uri(path: sessions, queryParameters: {'clientId': clientId}).toString();
  static const firebaseDiagnostics = '/dev/firebase-diagnostics';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final bootstrapState = ref.watch(bootstrapControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.bootstrap,
    redirect: (context, state) =>
        _redirectForBootstrapState(bootstrapState, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (context, state) => const BootstrapGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.bootstrap,
        builder: (context, state) => const BootstrapGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.acceptInvite,
        builder: (context, state) =>
            AcceptInviteScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: AppRoutes.createGym,
        builder: (context, state) => const CreateGymScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShellScaffold(
          navigationShell: navigationShell,
          barMenuPath: AppRoutes.barMenu,
          statsPath: AppRoutes.stats,
        ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.app,
                builder: (context, state) => const AuthenticatedShellScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.clients,
                builder: (context, state) => const ClientsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.sessions,
                builder: (context, state) => SessionsScreen(
                  clientId: state.uri.queryParameters['clientId'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.finance,
                builder: (context, state) => const FinanceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.packages,
                builder: (context, state) => const PackagesScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.stats,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.barMenu,
        builder: (context, state) => const BarMenuScreen(),
      ),
      GoRoute(
        path: AppRoutes.barGuestPos,
        builder: (context, state) => const BarPosScreen(isGuestMode: true),
      ),
      GoRoute(
        path: AppRoutes.barAdmin,
        builder: (context, state) => const BarAdminScreen(),
      ),
      GoRoute(
        path: AppRoutes.createClient,
        builder: (context, state) => const CreateClientScreen(),
      ),
      GoRoute(
        path: AppRoutes.createPackage,
        builder: (context, state) => const CreatePackageScreen(),
      ),
        GoRoute(
          path: AppRoutes.editPackage,
          builder: (context, state) {
            final package = state.extra;
            if (package is! GymPackageSummary) {
            return const Directionality(
              textDirection: TextDirection.ltr,
              child: Center(child: Text('Missing package edit context')),
            );
          }

            return CreatePackageScreen(initialPackage: package);
          },
        ),
        GoRoute(
          path: AppRoutes.packageSubscriptionAction,
          builder: (context, state) {
            final args = state.extra;
            if (args is! ActivatePackageRouteArgs) {
              return const Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: Text('Missing sold subscription action context'),
                ),
              );
            }

            return ActivatePackageScreen(
              clientId: args.clientId,
              clientName: args.clientName,
              clientPhone: args.clientPhone,
              editSubscription: args.editSubscription,
              editStartOnly: args.editStartOnly,
              popOnSuccess: args.popOnSuccess,
            );
          },
        ),
        GoRoute(
          path: '${AppRoutes.clients}/:clientId',
          builder: (context, state) => ClientDetailScreen(
          clientId: state.pathParameters['clientId'] ?? '',
        ),
      ),
      GoRoute(
        path: '${AppRoutes.clients}/:clientId/activate-package',
        builder: (context, state) => ActivatePackageScreen(
          clientId: state.pathParameters['clientId'] ?? '',
        ),
      ),
      GoRoute(
        path: '${AppRoutes.clients}/:clientId/collect-payment',
        builder: (context, state) => CollectPaymentScreen(
          clientId: state.pathParameters['clientId'] ?? '',
        ),
      ),
      GoRoute(
        path: '${AppRoutes.clients}/:clientId/bar',
        builder: (context, state) => BarPosScreen(
          clientId: state.pathParameters['clientId'] ?? '',
          sessionId: state.uri.queryParameters['sessionId'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.staff,
        builder: (context, state) => const StaffScreen(),
      ),
      GoRoute(
        path: AppRoutes.createStaff,
        builder: (context, state) => const CreateStaffScreen(),
      ),
      GoRoute(
        path: AppRoutes.staffInvites,
        builder: (context, state) => const InvitesScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.firebaseDiagnostics,
          builder: (context, state) => const FirebaseDiagnosticsScreen(),
        ),
    ],
  );
});

String? _redirectForBootstrapState(BootstrapState state, String location) {
  if (kDebugMode && location == AppRoutes.firebaseDiagnostics) {
    return null;
  }

  if (location == AppRoutes.acceptInvite &&
      (state.isLoading || state.isUnauthenticated)) {
    return null;
  }

  if (state.isLoading || state.hasBootstrapError) {
    return location == AppRoutes.bootstrap ? null : AppRoutes.bootstrap;
  }

  if (state.needsOnboarding) {
    if (location == AppRoutes.createGym || location == AppRoutes.verifyEmail) {
      return null;
    }

    return AppRoutes.createGym;
  }

  if (state.isAuthenticated) {
    if (location == AppRoutes.app ||
        location == AppRoutes.clients ||
        location == AppRoutes.createClient ||
        location == AppRoutes.stats ||
        location.startsWith('${AppRoutes.clients}/') ||
        location == AppRoutes.sessions ||
        location == AppRoutes.finance ||
        location == AppRoutes.packages ||
        location == AppRoutes.createPackage ||
        location == AppRoutes.editPackage ||
        location == AppRoutes.packageSubscriptionAction ||
        location == AppRoutes.barMenu ||
        location == AppRoutes.barGuestPos ||
        location == AppRoutes.barAdmin ||
        location == AppRoutes.staff ||
        location == AppRoutes.createStaff ||
        location == AppRoutes.staffInvites ||
        location == AppRoutes.verifyEmail) {
      return null;
    }

    return AppRoutes.app;
  }

  if (state.requiresEmailVerification) {
    return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;
  }

  if (state.isUnauthenticated) {
    if (location == AppRoutes.login ||
        location == AppRoutes.register ||
        location == AppRoutes.forgotPassword ||
        location == AppRoutes.acceptInvite) {
      return null;
    }

    return AppRoutes.login;
  }

  return AppRoutes.bootstrap;
}
