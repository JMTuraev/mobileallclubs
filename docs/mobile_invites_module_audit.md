# Mobile Invites Module Audit

## 1. Source Of Truth

Working web / backend sources inspected:

- `D:\agentallclubs\src\services\inviteService.js`
- `D:\agentallclubs\src\pages\AcceptInvitePage.jsx`
- `D:\agentallclubs\src\App.jsx`
- `D:\agentallclubs\src\context\AuthContext.jsx`
- `D:\agentallclubs\functions\index.js`

Confirmed callable set:

- `sendInvite`
- `cancelInvite`
- `resendInvite`
- `getGymInvites`
- `validateInviteToken`
- `acceptInvite`

## 2. Mobile Implementation

Implemented mobile surfaces:

- owner-only `Staff invites` route
- send-invite form using the exact `sendInvite` callable payload
- invite history list from `getGymInvites`
- invite actions:
  - `Resend`
  - `Cancel`
- public `accept-invite` route using token query param
- exact accept flow:
  1. `validateInviteToken`
  2. `createUserWithEmailAndPassword`
  3. callable `acceptInvite`

Mobile implementation files:

- `lib/features/invites/domain/gym_invite_summary.dart`
- `lib/features/invites/application/invite_service.dart`
- `lib/features/invites/application/invite_providers.dart`
- `lib/features/invites/presentation/invites_screen.dart`
- `lib/features/invites/presentation/accept_invite_screen.dart`
- `lib/features/staff/presentation/staff_screen.dart`
- `lib/core/routing/app_router.dart`
- `test/widget_test.dart`

Practical mobile completion note:

- after successful invite acceptance, mobile sends a best-effort verification email through FirebaseAuth and then routes into the existing verify-email gate
- this does not change backend contracts, DB structure, rules, or schema

## 3. Verification

Local verification:

- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build apk --debug`: PASS

Widget coverage added:

- owner can open the invite-management route from the staff module
- invite-management screen renders the real send form and invite list shell
- accept-invite screen shows a safe missing-token state

Android verification:

- PARTIAL
- Samsung became visible and installable in this turn:
  - `adb devices -l`: PASS
  - `flutter devices`: PASS
  - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS
- Samsung owner-session verification completed for:
  - app reopened successfully
  - owner profile restored successfully
  - `Open staff management`: PASS
  - `Staff invites` route open: PASS
  - `Send staff invite` form visible: PASS
  - `Invite history` empty-state visible: PASS
  - exact empty-state text: `No invites found.`
- Samsung submit verification:
  - disposable invite payload used:
    - `fullName = CodexInviteQA`
    - `phone = 998901234571`
    - `email = codexinvite20260406a@gmail.com`
  - the working `sendInvite` callable completed on Samsung:
    - success card text: `Invite created successfully.`
    - latest invite token shown on-device: `7IjxlNQ6pMPi0uk4N0hv`
  - supporting screenshot:
    - `build/mobile_invites_send_success.png`
- Samsung history verification after the mobile error-surfacing fix:
  - `Invite history` no longer silently falls back to an empty list
  - the exact on-device failure is now visible:
    - `Exception: INTERNAL`
  - supporting screenshot:
    - `build/mobile_invites_internal_error.png`
- Samsung token-route verification:
  - app data was cleared so the route could open in an unauthenticated state
  - direct token route opened successfully:
    - `/accept-invite?token=7IjxlNQ6pMPi0uk4N0hv`
  - Samsung showed the exact validated invite data:
    - title `Accept staff invite`
    - email `codexinvite20260406a@gmail.com`
    - role `staff`
    - gym `Di7qKRDQvrfSLZJnWZ1y`
    - prefilled full name `CodexInviteQA`
  - disposable password used:
    - `Codex4777`
  - keyboard-submit completed the exact mobile flow:
    1. `validateInviteToken`
    2. `createUserWithEmailAndPassword`
    3. callable `acceptInvite`
  - final Samsung result:
    - routed into `Verify email`
    - exact visible text:
      - `Email/password login succeeded, but codexinvite20260406a@gmail.com must be verified before entering the app.`
  - supporting screenshots:
    - `build/accept_invite_open.png`
    - `build/accept_invite_password_focus.png`
    - `build/accept_invite_confirm_focus.png`
    - `build/accept_invite_submit_result.png`

Truthful status:

- code is implemented, analyzed, tested, and built
- Samsung live proof is closed for:
  - route visibility and owner-side entry
  - successful `sendInvite` backend response
  - token validation through `validateInviteToken`
  - token-driven `acceptInvite` account creation flow
- Samsung live proof is still pending for:
  - `getGymInvites` successful history rendering
  - `resendInvite`
  - `cancelInvite`

## 4. Safe Limits Kept

- No backend code changed
- No Firestore rules changed
- No Firestore indexes changed
- No DB schema changed
- No invite collection path was guessed
- No callable names were guessed
- Existing auth/bootstrap flow remained intact

## 5. Exact Remaining Blockers

1. The exact `getGymInvites` callable currently surfaces `Exception: INTERNAL` on Samsung instead of returning invite rows.
2. Because invite history is blocked by that backend-side callable failure, `resendInvite` and `cancelInvite` cannot yet be exercised from the list UI.
3. Deep-link / universal-link handling is not implemented in mobile yet; the route exists inside the app and accepts the token query param.
4. ADB text entry for email remains fragile on this Samsung device, especially around `@`.

## 6. Safe Next Actions

1. Treat `sendInvite` as Samsung-verified PASS using the visible success card and token.
2. Treat `acceptInvite` as Samsung-verified PASS using the token route and verify-email gate proof.
3. Keep DB/backend unchanged and document `getGymInvites` as a live backend blocker until the callable stops returning `INTERNAL`.
4. Once invite-history returns rows again, close `resendInvite` and `cancelInvite` on Samsung.
