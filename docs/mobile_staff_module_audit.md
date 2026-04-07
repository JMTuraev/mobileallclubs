# Mobile Staff Module Audit

Status: Owner-only staff module, create-staff callable, and staff-management write actions implemented from the working web route; core owner/staff access and the full create/edit/deactivate/reactivate/remove cycle are Samsung-verified
Audit date: 2026-04-07
Workspace: `D:\mobileallclubs`

## 1. Exact Source Of Truth

Working web repo:

- `D:\agentallclubs — копия`

Audited files:

- `D:\agentallclubs — копия\src\App.jsx`
- `D:\agentallclubs — копия\src\pages\StaffList.jsx`
- `D:\agentallclubs — копия\src\pages\staff\domain\useStaffs.js`
- `D:\agentallclubs — копия\src\components\RequireRole.jsx`
- `D:\agentallclubs — копия\src\services\staffService.js`
- `D:\agentallclubs\src\pages\staff\StaffPage.jsx`
- `D:\agentallclubs\src\services\inviteService.js`
- `D:\agentallclubs — копия\src\pages\staff\CreateStaffPage.jsx`
- `D:\agentallclubs — копия\src\firebase.js`
- `D:\agentallclubs — копия\functions\index.js`

## 2. Real Staff Contract

Exact working web route:

- `/app/staffs`

Exact access rule used by the working web app:

- owner only
- gym context required

Exact runtime data source used by the working route:

- `gyms/{gymId}/users`

Exact runtime query shape:

- realtime collection stream via `onSnapshot`
- no Firestore `where` clause in the live route
- no explicit ordering in the live route
- staff filtering happens locally in memory with `role == "staff"`

Exact visible fields used by the working web route:

- `fullName`
- `phone`
- `image`
- `isActive`
- `role`

Exact working create-staff callable contract:

- callable name: `createStaff`
- access: authenticated `owner` with resolved `gymId`
- request payload:
  - `email`
  - `password`
  - `fullName`
  - `phone`
- success response includes:
  - `success`
  - `userId`
  - `email`

Important callable behavior discovered from backend source:

- creates a real Firebase Auth user
- sets `emailVerified: true`
- writes the global user doc at `users/{uid}`
- writes the tenant membership doc at `gyms/{gymId}/users/{uid}`
- writes `role: "staff"` in both places
- sets custom claims with `gymId` and `role: "staff"`

Exact additional staff-management callables discovered from the working web source:

- `deactivateStaff`
- `removeStaff`
- `getActiveStaff`

Exact additional request payloads:

- `deactivateStaff`
  - `userId`
  - `isActive`
- `removeStaff`
  - `userId`
- `getActiveStaff`
  - no payload required by the working web helper

Important runtime note:

- `staffService.getStaffByGym()` also exists and queries global `users`
- the working `/app/staffs` route in `App.jsx` does not use that service
- the live route uses `StaffList` + `useStaffs`
- mobile mirrors the actual working route contract, not the unused helper query
- exact backend nuance discovered during Samsung verification:
  - `deactivateStaff` updates only the global `users/{uid}` document
  - `removeStaff` updates both `users/{uid}` and `gyms/{gymId}/users/{uid}`
  - mobile keeps the visible list on `gyms/{gymId}/users`, then syncs active-state with the exact `getActiveStaff` callable so owner actions reflect backend truth without guessing extra write paths

## 3. What Was Implemented In Mobile

- owner-only shell entry for staff
- owner-only read-only `Staff` route
- realtime stream from `gyms/{gymId}/users`
- local in-memory filter to `role == "staff"`
- owner-only `Create staff` route
- exact `createStaff` callable wrapper with the audited payload
- exact `deactivateStaff` callable wrapper for deactivate/reactivate
- exact `removeStaff` callable wrapper
- exact `getActiveStaff` callable helper
- active-state overlay synced from `getActiveStaff`
- exact `updateStaff` callable wrapper for safe staff-profile edits
- read-only staff cards with:
  - avatar or initials fallback
  - full name
  - phone
  - static `Staff` badge
  - `Active` / `Inactive` badge
- owner-only staff action buttons:
  - `Edit`
  - `Deactivate`
  - `Reactivate`
  - `Remove`
- loading, empty, error, and access-blocked states

Implementation files:

- `lib/features/staff/domain/gym_staff_summary.dart`
- `lib/features/staff/application/staff_providers.dart`
- `lib/features/staff/application/create_staff_service.dart`
- `lib/features/staff/presentation/staff_screen.dart`
- `lib/features/staff/presentation/create_staff_screen.dart`
- `lib/features/auth/presentation/authenticated_shell_screen.dart`
- `lib/core/routing/app_router.dart`

## 4. Verification

Local verification:

- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build apk --debug`: PASS
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS

Widget test coverage:

- authenticated shell exposes `Open staff` for owner sessions
- tapping `Open staff` opens the real read-only route
- staff rows render active and inactive badges
- expanded staff cards still render in the owner route after the new action buttons were added

Samsung verification:

- PASS
- owner session restored successfully
- `Open staff` appeared in the authenticated shell
- `Open staff` opened the real owner-only route
- Samsung showed:
  - gym `Rezone`
  - `1 staff`
  - `1 active`
  - returned row:
    - `Jafarali Turaev`
    - `997034444`
    - `Staff`
    - `Active`
- `Create staff` opened the real owner-only callable route
- real callable submission succeeded on Samsung
- Samsung staff list updated live after submit and showed:
  - `2 staff`
  - `2 active`
  - new returned row:
    - `Codex Staff QA`
    - `998901234568`
    - `Staff`
    - `Active`
- a second disposable staff account was created on Samsung with the simpler live-verification payload:
  - `fullName=CodexStaffQA2`
  - `phone=998901234569`
  - `email=codexstaff20260405b@gmail.com`
  - `password=Codex4777Codex4777`
- the owner-only staff list updated live after the second submit and showed:
  - `3 staff`
  - `3 active`
- the new staff account then signed in successfully on Samsung
- Samsung authenticated shell resolved:
  - primary identity `codexstaff20260405b@gmail.com`
  - role `staff`
  - exact global user doc `users/XeqIFJKK3Nh4I2c6jHLutzuGexZ2`
  - exact gym membership doc `gyms/Di7qKRDQvrfSLZJnWZ1y/users/XeqIFJKK3Nh4I2c6jHLutzuGexZ2`
- Samsung staff-authenticated shell exposed:
  - `Open clients`
  - `Open sessions`
- Samsung staff-authenticated shell did not expose:
  - `Open staff`
- Samsung verified staff access to:
  - `Clients`
  - `Sessions`
- owner-side `deactivateStaff` action now live-proves as:
  - `3 staff`
  - `2 active`
  - `Codex Staff QA`
  - `Inactive`
- owner-side `reactivateStaff` action now live-proves as:
  - `3 staff`
  - `3 active`
  - `Codex Staff QA`
  - `Active`
- owner-side `removeStaff` action now live-proves as:
  - `2 staff`
  - `2 active`
  - `CodexStaffQA2` disappeared from the live list
- owner-side `updateStaff` action now live-proves as:
  - `Edit staff` dialog opened on Samsung
  - disposable rename `CodexStaffQA2 -> CodexStaffQA2B`
  - inline success state `Staff updated.`
  - live row reflected the updated name `CodexStaffQA2B`

Evidence:

- `build/mobile_staff_live_final.png`
- `build/mobile_create_staff_reopen.png`
- `build/mobile_create_staff_result.png`
- `build/mobile_create_staff_filled_fixed.png`
- `build/mobile_create_staff_after_submit_simple.png`
- `build/mobile_staff_login_filled_simple.png`
- `build/mobile_staff_signin_result_simple.png`
- `build/mobile_staff_shell_after_scroll3.png`
- `build/mobile_staff_sessions_open2.png`
- `build/window_dump_staff_clients_open.xml`
- `build/mobile_staff_after_hybrid_open_final.png`
- `build/mobile_staff_after_hybrid_scroll_for_inactive.png`
- `build/mobile_staff_reactivate_confirm.png`
- `build/mobile_staff_reactivate_result.png`
- `build/mobile_staff_remove_confirm.png`
- `build/mobile_staff_remove_result.png`
- `build/staff_edit_form_open.png`
- `build/staff_edit_name_appended.png`
- `build/staff_edit_save_result_success.png`

## 5. Safe Limits Kept

- No backend code changed
- No Firestore rules changed
- No indexes changed
- No schema changed
- No guessed collection paths used
- No alternate staff write paths were invented
- Only the explicit audited `createStaff` callable was invoked from mobile
- Only the explicit audited `deactivateStaff`, `removeStaff`, `getActiveStaff`, and `updateStaff` contracts were added for staff management

## 6. Exact Remaining Blockers

1. Backend `updateStaff` still writes only the global `users/{uid}` doc, so mobile keeps a local overlay for immediate name/phone reflection instead of inventing an extra Firestore write.
2. Backend `deactivateStaff` still writes only the global `users/{uid}` doc, so mobile syncs active-state through the explicit `getActiveStaff` callable.
3. The first disposable staff login attempt failed with `The supplied auth credential is incorrect, malformed or has expired.` because the initial long-email ADB typing path was unreliable.
4. A transient Samsung USB/ADB disconnect still happens intermittently during long live-verification runs.

## 7. Safe Next Actions

1. Keep staff write scope limited to the explicit audited callables and the read-only list/query already proven safe.
2. Reuse the same disposable staff row if a later regression check is needed for `updateStaff`.
3. Continue with the next module only from the working web source-of-truth.
