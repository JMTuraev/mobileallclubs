# Mobile Auth Bootstrap Audit

Status: Real auth/bootstrap, super-admin fallback bootstrap, and live onboarding verified
Audit date: 2026-04-06
Workspace: `D:\mobileallclubs`

## 1. What Was Implemented

- Real Firebase email/password login via `signInWithEmailAndPassword`
- Real account creation via `createUserWithEmailAndPassword`
- Real password reset via `sendPasswordResetEmail`
- Real verification email resend via `sendEmailVerification`
- Auth state restore through FirebaseAuth
- Protected routing for:
  - `/bootstrap`
  - `/auth/login`
  - `/auth/register`
  - `/auth/forgot-password`
  - `/auth/create-gym`
  - `/auth/verify-email`
  - `/app`
  - `/dev/firebase-diagnostics` in debug mode only
- Current-session resolution aligned to the web `AuthContext` contract:
  1. read `users/{uid}`
  2. stop early for `super_admin`
  3. otherwise resolve `users/{uid}.gymId`
  4. read `gyms/{gymId}/users/{uid}`
  5. read `gyms/{gymId}`
- Onboarding-aware session behavior aligned to web:
  - missing `users/{uid}` is treated as onboarding, not fatal
  - missing `gymId` is treated as onboarding, not guessed
- Exact super-admin bootstrap fallback aligned to web:
  - allowlist from `shared/super-admin.json`
  - callable `syncSuperAdminAccess`
  - ID-token refresh after sync
  - local fallback to `super_admin` if the email is allowlisted and the doc is still missing
- Real onboarding callable wrapper:
  - `createGymAndUser({ gymData: { name, city, phone, firstName, lastName } })`
- Real onboarding-lock recovery callable wrapper:
  - `clearOnboardingLock({ uid })`
- Real onboarding recovery entry in the create-gym flow:
  - shows only after a real onboarding error
  - calls `clearOnboardingLock`
  - invalidates bootstrap state and returns to `/bootstrap`
- Safe post-onboarding navigation now returns to `/bootstrap` so routing settles from real refreshed session state

Implementation files:

- `lib/models/auth_bootstrap_models.dart`
- `lib/core/config/super_admin_config.dart`
- `lib/core/services/auth_bootstrap_resolver.dart`
- `lib/core/services/onboarding_service.dart`
- `lib/core/services/firebase_clients.dart`
- `lib/features/bootstrap/application/bootstrap_state.dart`
- `lib/features/bootstrap/application/bootstrap_controller.dart`
- `lib/core/routing/app_router.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/auth/presentation/register_screen.dart`
- `lib/features/auth/presentation/create_gym_screen.dart`
- `lib/features/auth/presentation/forgot_password_screen.dart`
- `lib/features/auth/presentation/verify_email_screen.dart`
- `lib/features/auth/presentation/authenticated_shell_screen.dart`

## 2. What Was Verified On Samsung

Previously verified on Samsung:

- app launches on device
- `Firebase.initializeApp` succeeds
- FirebaseAuth / Firestore / Functions clients initialize
- real owner-account sign-in succeeds
- exact `users/{uid}` / `gyms/{gymId}/users/{uid}` / `gyms/{gymId}` resolution succeeds
- logout returns to the unauthenticated gate

Additionally verified on Samsung in this pass:

- real register via `createUserWithEmailAndPassword`
- route transition from register to `Create gym`
- real onboarding submit via `createGymAndUser`
- route transition from onboarding to `Verify email`

Live onboarding test data used:

- email: `codexmobile202604050043@example.com`
- password used by the created auth account: `Codex4777Codex4777`
- firstName: `Codex`
- lastName: `Mobile`
- phone: `+998 90 123 45 67`
- gym name: `CodexMobileQA20260405`
- city: `Tashkent`

Why the `Verify email` screen is strong onboarding evidence:

- In mobile bootstrap, `needsOnboarding` is checked before `requiresEmailVerification`.
- Reaching `Verify email` after `createGymAndUser` means the app no longer considers this user onboarding-incomplete.
- That implies the production contract now resolves far enough for the session to leave the onboarding gate.

## 3. Whether Login Is Real Or Blocked

Status: PASS

- Login is real and already live-verified on Samsung.
- The login screen now also links into the real register flow and real forgot-password flow.

## 4. Whether User Doc Resolution Is Real Or Blocked

Status: PASS

- User resolution uses the exact web path `users/{uid}`.
- Missing `users/{uid}` now correctly routes to onboarding instead of guessing or crashing.

## 5. Whether Gym Resolution Is Real Or Blocked

Status: PASS

- Gym resolution uses the exact web chain:
  - `users/{uid}.gymId`
  - `gyms/{gymId}/users/{uid}`
  - `gyms/{gymId}`

## 6. Whether Role Resolution Is Real Or Blocked

Status: PASS

- Role resolution uses:
  - `users/{uid}.role`
  - mirrored `gyms/{gymId}/users/{uid}.role`
- Implemented role values:
  - `owner`
  - `staff`
  - `super_admin`

## 7. Whether Onboarding Contract Is Real Or Blocked

Status: PASS

- The exact onboarding callable and payload are now visible from the web source.
- Mobile now uses the discovered `gymData` payload without guessing field names.
- Samsung now live-verified the onboarding path end-to-end up to the expected `Verify email` gate.

## 8. Exact Remaining Blockers

1. Live Samsung verification still covers only the `owner` path.
2. The `/auth/verify-email` route is now live-covered for an unverified account, but actual email-confirm completion was not performed.
3. Local `flutter run` debug attach is still flaky because of the existing `adb forward` / `AdbWinApi.dll.dat` issue.
4. `staff` and `super_admin` branches are still not live-verified in this pass.
5. Feature modules remain intentionally out of scope in this pass.

## 9. Safe Next Actions

1. If you explicitly want production onboarding exercised, run it with a dedicated disposable account you are comfortable creating in production.
2. Otherwise keep this pass read-safe and move to the first real read-only owner module.
3. If alternate role branches matter next, verify `staff` and `super_admin` on Samsung with real credentials.
4. Keep DB shape unchanged and continue deriving mobile behavior from the working web source.
