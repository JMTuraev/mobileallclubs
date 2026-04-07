# Mobile Full Parity Audit

Status: Blocked by missing production source  
Audit date: 2026-04-04  
Workspace: `D:\mobileallclubs`

## Executive Summary

- The checked-out repository is a Flutter mobile scaffold, not the existing AllClubs production workspace.
- The code under `lib/` contains bootstrap and placeholder module artifacts, but no audited owner or staff business implementation.
- The current workspace does not contain the web app, backend, Cloud Functions, Firestore rules, schema contracts, or permission logic required for real mobile parity work.
- Because the production source of truth is absent, no real auth, role, dashboard, clients, subscriptions, sessions, finance, analytics, staff, settings, billing, or POS module can be implemented safely from this checkout alone.
- As a prompt-compliant cleanup step, live placeholder module navigation should not remain exposed in the running app.

## Verified Repository Evidence

### Flutter App Structure

- Root Flutter app exists with platform folders for Android, iOS, web, Windows, macOS, and Linux.
- `lib/main.dart` boots a Riverpod `ProviderScope`.
- `lib/app/app.dart` builds a `MaterialApp.router`.
- `lib/core/routing/app_router.dart` previously exposed placeholder module routes and now must be treated as a cleanup target, not as real product parity.

### Dependencies

Confirmed in `pubspec.yaml`:

- `go_router`
- `flutter_riverpod`

Not declared in `pubspec.yaml`:

- `firebase_core`
- `firebase_auth`
- `cloud_firestore`
- `cloud_functions`
- `in_app_purchase`

This means Firebase-native platform config files may exist, but Firebase is not actually wired at the Dart app layer yet.

### Native Firebase Configuration

Observed:

- `android/app/google-services.json`
- `ios/Runner/google-services.json`

Not observed:

- `ios/Runner/GoogleService-Info.plist`

The Android file suggests a Firebase project exists, but the iOS config is not in the standard Flutter Firebase filename/format expected for iOS app bootstrap.

### Placeholder Artifact Inventory

Observed placeholder-oriented mobile artifacts:

- `lib/features/dashboard/presentation/dashboard_screen.dart`
- `lib/features/clients/presentation/clients_screen.dart`
- `lib/features/sessions/presentation/sessions_screen.dart`
- `lib/features/more/presentation/more_screen.dart`
- `lib/features/shell/presentation/foundation_shell.dart`
- `lib/core/widgets/foundation_page.dart`
- `lib/core/widgets/module_status_card.dart`
- `lib/core/widgets/status_pill.dart`
- `lib/models/module_readiness_status.dart`

These files are not evidence of real parity. They are scaffold artifacts and must not be treated as completed business modules.

### Not Present Anywhere In This Workspace

- existing website source
- backend or Cloud Functions source
- Firestore rules
- Firestore indexes
- `firebase.json`
- role-resolution logic
- gym-resolution logic
- auth flow implementation
- billing verification backend
- production route guards
- business module source for clients, subscriptions, sessions, finance, analytics, staff, settings, or POS

## Module Audit Result

| Area | Audit result | Reason |
| --- | --- | --- |
| Auth/bootstrap | Blocked | No production auth flow or Firebase Dart wiring |
| Role resolution | Blocked | No production role model, route guard, or permission source |
| Gym resolution | Blocked | No resolver logic or source documents |
| Dashboard | Blocked | No audited web dashboard or data contracts |
| Clients | Blocked | No client list/detail contracts or source modules |
| Packages/subscriptions | Blocked | No package/subscription rules or mutation contracts |
| Sessions | Blocked | No start/end session authority or state machine source |
| Finance | Blocked | No ledger or aggregate truth source |
| Analytics | Blocked | No backend aggregate documents or generation logic |
| Staff management | Blocked | No permission rules or mutation paths |
| Settings | Blocked | No role-aware settings source |
| Billing | Blocked | No verified backend entitlement path |
| Bar/POS | Blocked | No evidence the module exists in source |

## Role And Permission Audit

The task brief names `OWNER` and `STAFF`, but exact permission boundaries cannot be derived from this repository.

Not present:

- owner-only route definitions
- staff-only route definitions
- permission checks
- role documents
- Firestore rules proving access boundaries
- backend mutation guards

Therefore any owner/staff parity claim would be guesswork and unsafe.

## Safe Engineering Conclusion

The current workspace does not provide enough contract truth to implement production-safe mobile parity. The only defensible path is:

1. document the blocker clearly
2. remove fake live module exposure from the app
3. wait for the real website/backend source before wiring business modules

## Required Unblockers

To continue with real implementation, the workspace must include or point to:

- the current AllClubs website source
- the current backend or Cloud Functions source
- Firestore rules and indexes
- role-resolution and gym-resolution logic
- any billing verification or entitlement backend already used by production

Without those inputs, mobile parity work must remain documentation-first and non-deceptive.
