import '../../../models/auth_bootstrap_models.dart';

enum BootstrapStage {
  loading,
  bootstrapError,
  unauthenticated,
  onboardingRequired,
  emailVerificationRequired,
  authenticated,
}

class BootstrapState {
  static const loginMethodDescription =
      'Firebase email/password via signInWithEmailAndPassword.';
  static const userProfileContract = 'users/{uid}';
  static const gymResolutionContract =
      'users/{uid}.gymId -> gyms/{gymId}/users/{uid} -> gyms/{gymId}';
  static const roleResolutionContract =
      'users/{uid}.role mirrored at gyms/{gymId}/users/{uid}.role';
  static const onboardingContract =
      'createGymAndUser({ gymData: { name, city, phone, firstName, lastName } })';

  const BootstrapState._({
    required this.stage,
    this.message,
    this.session,
    required this.interactiveLoginEnabled,
    required this.loginMessage,
    required this.userProfileResolutionEnabled,
    required this.userProfileMessage,
    required this.gymResolutionEnabled,
    required this.gymResolutionMessage,
    required this.roleResolutionEnabled,
    required this.roleResolutionMessage,
  });

  const BootstrapState.loading()
    : this._(
        stage: BootstrapStage.loading,
        interactiveLoginEnabled: false,
        loginMessage: loginMethodDescription,
        userProfileResolutionEnabled: true,
        userProfileMessage: userProfileContract,
        gymResolutionEnabled: true,
        gymResolutionMessage: gymResolutionContract,
        roleResolutionEnabled: true,
        roleResolutionMessage: roleResolutionContract,
      );

  const BootstrapState.bootstrapError(String message)
    : this._(
        stage: BootstrapStage.bootstrapError,
        message: message,
        interactiveLoginEnabled: false,
        loginMessage: loginMethodDescription,
        userProfileResolutionEnabled: true,
        userProfileMessage: userProfileContract,
        gymResolutionEnabled: true,
        gymResolutionMessage: gymResolutionContract,
        roleResolutionEnabled: true,
        roleResolutionMessage: roleResolutionContract,
      );

  const BootstrapState.unauthenticated()
    : this._(
        stage: BootstrapStage.unauthenticated,
        interactiveLoginEnabled: true,
        loginMessage: loginMethodDescription,
        userProfileResolutionEnabled: true,
        userProfileMessage: userProfileContract,
        gymResolutionEnabled: true,
        gymResolutionMessage: gymResolutionContract,
        roleResolutionEnabled: true,
        roleResolutionMessage: roleResolutionContract,
      );

  const BootstrapState.onboardingRequired(ResolvedAuthSession session)
    : this._(
        stage: BootstrapStage.onboardingRequired,
        session: session,
        interactiveLoginEnabled: false,
        loginMessage: loginMethodDescription,
        userProfileResolutionEnabled: true,
        userProfileMessage: userProfileContract,
        gymResolutionEnabled: true,
        gymResolutionMessage: gymResolutionContract,
        roleResolutionEnabled: true,
        roleResolutionMessage: roleResolutionContract,
      );

  const BootstrapState.emailVerificationRequired(ResolvedAuthSession session)
    : this._(
        stage: BootstrapStage.emailVerificationRequired,
        session: session,
        interactiveLoginEnabled: false,
        loginMessage: loginMethodDescription,
        userProfileResolutionEnabled: true,
        userProfileMessage: userProfileContract,
        gymResolutionEnabled: true,
        gymResolutionMessage: gymResolutionContract,
        roleResolutionEnabled: true,
        roleResolutionMessage: roleResolutionContract,
      );

  const BootstrapState.authenticated(ResolvedAuthSession session)
    : this._(
        stage: BootstrapStage.authenticated,
        session: session,
        interactiveLoginEnabled: true,
        loginMessage: loginMethodDescription,
        userProfileResolutionEnabled: true,
        userProfileMessage: userProfileContract,
        gymResolutionEnabled: true,
        gymResolutionMessage: gymResolutionContract,
        roleResolutionEnabled: true,
        roleResolutionMessage: roleResolutionContract,
      );

  final BootstrapStage stage;
  final String? message;
  final ResolvedAuthSession? session;
  final bool interactiveLoginEnabled;
  final String loginMessage;
  final bool userProfileResolutionEnabled;
  final String userProfileMessage;
  final bool gymResolutionEnabled;
  final String gymResolutionMessage;
  final bool roleResolutionEnabled;
  final String roleResolutionMessage;

  AuthenticatedUserSnapshot? get user => session?.authUser;
  bool get isLoading => stage == BootstrapStage.loading;
  bool get hasBootstrapError => stage == BootstrapStage.bootstrapError;
  bool get isUnauthenticated => stage == BootstrapStage.unauthenticated;
  bool get needsOnboarding => stage == BootstrapStage.onboardingRequired;
  bool get requiresEmailVerification =>
      stage == BootstrapStage.emailVerificationRequired;
  bool get isAuthenticated => stage == BootstrapStage.authenticated;
}
