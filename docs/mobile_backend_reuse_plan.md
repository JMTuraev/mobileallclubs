# Mobile Backend Reuse Plan

Status: Reuse intent defined, implementation blocked by missing backend source

## Non-Negotiable Reuse Rules

- Existing backend and database logic remain authoritative.
- Mobile must adapt to current production truth, not recreate it locally.
- Any backend change, if later required, must be additive, backward compatible, documented first, and explicitly human-approved.

## What Is Actually Reusable From This Workspace

Confirmed local assets:

- Flutter app scaffold
- GoRouter setup
- Riverpod setup
- Android Firebase config file at `android/app/google-services.json`

Partially present but not implementation-ready:

- iOS Firebase-related file exists as `ios/Runner/google-services.json`
- standard iOS `GoogleService-Info.plist` was not observed

Not reusable because source is absent:

- Firebase Auth flow contracts
- Firestore collection paths
- Cloud Function names or payload contracts
- role or gym resolution rules
- subscription/session state machine rules
- finance or analytics aggregates
- billing verification endpoints

## Current Safe Reuse Boundary

Mobile may safely reuse only generic app infrastructure right now:

- app bootstrap shell
- provider boundaries
- router boundaries
- loading/error/empty state patterns
- repository and service interfaces once real contracts are known

Mobile may not safely reuse or infer business contracts for:

- auth
- roles
- gym selection
- clients
- subscriptions
- sessions
- finance
- analytics
- staff
- settings
- billing
- POS

## Practical Next Reuse Checks

Before any real backend wiring starts, verify all of the following:

1. add the production website/backend source to the workspace
2. confirm actual Firebase Dart dependencies required by the mobile app
3. confirm standard iOS Firebase config is present and valid
4. inventory real callable/function names and request shapes
5. inventory authoritative Firestore read paths
6. inventory backend-owned state transitions

## Writes That Must Stay Backend-Owned

Until proven otherwise from source:

- package activation and renewal
- session start and end
- finance mutations
- analytics generation
- role changes
- staff management mutations
- billing verification and entitlement updates

## Approval-Gated Backend Changes

No backend change is proposed yet.

Reason:

- the current workspace does not contain enough backend source to justify even a minimal additive proposal

If a missing backend capability is later confirmed from real source, document it in `docs/mobile_blocked_backend_changes.md` before implementation.
