# Mobile Firebase Backend Connection Audit

Audit date: 2026-04-07
Workspace: `D:\mobileallclubs`

## 1. Executive Summary

Status: Android mobile foundation connected, auth/bootstrap live-proven, onboarding live-proven, the core client/package/session write loop is Samsung-verified, photo-backed create-client is Samsung-verified, package-admin CRUD plus sold-subscription action routes are Samsung-verified, and analytics/delete utility routes are now Samsung-verified

One-line reason:

- Firebase bootstrap, live owner-path auth, exact user/gym/role resolution, the real web onboarding callable contract, and the first owner-only staff route are now all wired into the Flutter mobile app without changing DB shape or backend code.

## 2. Audited Source Of Truth

Primary working web repo:

- `D:\agentallclubs`

Canonical files used in this pass:

- `D:\agentallclubs — копия\src\pages\Login.jsx`
- `D:\agentallclubs — копия\src\context\AuthContext.jsx`
- `D:\agentallclubs — копия\src\services\onboardingService.js`
- `D:\agentallclubs — копия\src\pages\CreateClub.jsx`
- `D:\agentallclubs — копия\src\pages\VerifyEmail.jsx`
- `D:\agentallclubs — копия\src\pages\StaffList.jsx`
- `D:\agentallclubs — копия\src\pages\staff\domain\useStaffs.js`
- `D:\agentallclubs — копия\src\components\RequireRole.jsx`
- `D:\agentallclubs — копия\src\pages\staff\CreateStaffPage.jsx`
- `D:\agentallclubs — копия\src\firebase.js`
- `D:\agentallclubs — копия\functions\index.js`

Key backend truths adopted exactly:

- projectId: `allclubs`
- Firestore location: `asia-south1`
- Functions region: `asia-south1`
- global user doc: `users/{uid}`
- tenant root: `gyms/{gymId}`
- tenant membership: `gyms/{gymId}/users/{uid}`
- stable roles: `owner`, `staff`, `super_admin`
- auth method: Firebase email/password
- onboarding callable: `createGymAndUser`
- onboarding payload: `gymData = { name, city, phone, firstName, lastName }`
- owner-only staff callable: `createStaff`
- staff callable payload: `{ email, password, fullName, phone }`

## 3. Mobile Implementation Status

Implemented in mobile:

- Android Firebase bootstrap through `Firebase.initializeApp(...)`
- FirebaseAuth client provider
- FirebaseFirestore client provider
- FirebaseFunctions client provider pinned to `asia-south1`
- FirebaseAuth session restore
- real login
- real register
- real password reset
- real verify-email resend
- exact current-user / gym / role resolver
- onboarding-aware bootstrap
- exact `createGymAndUser` wrapper using the discovered web payload
- exact super-admin bootstrap fallback via `syncSuperAdminAccess`
- exact `clearOnboardingLock` callable wrapper
- first real read-only clients module
- client profile read-only detail route
- first client write slice:
  - real `createClient` callable wrapper
  - exact Firebase Storage photo upload path for optional client images
  - owner-only `archiveClient` callable wrapper
  - real card bind/remove transaction wrapper
  - real `startSession` / `endSession` callable wrappers
  - real `Create client` route
  - list/detail quick client actions
- real package-sale slice:
  - realtime packages stream
  - exact `createSubscription` callable wrapper
  - exact `updateSubscription` callable wrapper
  - owner-only activate / deactivate / cancel subscription actions
  - exact `updateSubscriptionStartDate` callable wrapper
  - exact payment-method payload shape
  - UTC-based default start date aligned to the working web drawer
 - real package-admin slice:
   - exact `createPackage` callable wrapper
   - exact `updatePackage` callable wrapper
   - exact `deletePackage` callable wrapper
   - owner-only create/edit/delete actions
   - staff-visible read-only package-template list
   - sold-packages tab backed by `gyms/{gymId}/subscriptions`
   - owner-only sold-row `Edit` / `Replace` route entry using the shared activation screen
- first real read-only sessions module
- bar admin slice:
  - exact `holdCheck` callable wrapper
  - exact `refundCheck` callable wrapper
  - exact `checkClientDebt` callable wrapper
  - owner-only bar admin route
  - exact `createBarCategory` / `updateBarCategory` / `deleteBarCategory`
  - exact `createBarProduct` / `updateBarProduct` / `deleteBarProduct`
  - exact `createBarIncoming` / `deleteBarIncoming`
  - exact bar-product Firebase Storage upload path
- client finance read-only summary
- finance payment actions:
  - real `createTransaction` collect-payment wrapper
  - real `createTransaction(type=payment_reverse)` reverse wrapper
  - real `createTransaction(type=payment)` restore wrapper
- owner-only read-only staff module
- owner-only create-staff route and callable wrapper
- owner-only dashboard route backed by exact `getOwnerAnalytics`
- client detail analytics card backed by exact `getClientInsights`
- staff-management action slice:
  - exact `deactivateStaff` callable wrapper
  - exact `removeStaff` callable wrapper
  - exact `getActiveStaff` callable helper
  - hybrid staff-state sync so the owner route stays on `gyms/{gymId}/users` while active-state follows the explicit backend callable truth
- protected authenticated shell entry
- keyboard-aware authenticated shell dock behavior for mobile forms
- debug-only Firebase diagnostics route

Primary implementation files:

- `lib/core/services/firebase_bootstrap.dart`
- `lib/core/services/firebase_clients.dart`
- `lib/core/services/firebase_runtime_diagnostics.dart`
- `lib/core/services/auth_bootstrap_resolver.dart`
- `lib/core/config/super_admin_config.dart`
- `lib/core/services/onboarding_service.dart`
- `lib/features/bootstrap/application/bootstrap_controller.dart`
- `lib/features/bootstrap/application/bootstrap_state.dart`
- `lib/features/bootstrap/presentation/bootstrap_gate_screen.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/auth/presentation/register_screen.dart`
- `lib/features/auth/presentation/create_gym_screen.dart`
- `lib/features/auth/presentation/forgot_password_screen.dart`
- `lib/features/auth/presentation/verify_email_screen.dart`
- `lib/features/auth/presentation/authenticated_shell_screen.dart`
- `lib/features/clients/application/client_actions_service.dart`
- `lib/features/clients/presentation/create_client_screen.dart`
- `lib/features/clients/presentation/start_session_dialog.dart`
- `lib/features/packages/application/package_providers.dart`
- `lib/features/packages/application/subscription_sale_service.dart`
- `lib/features/packages/presentation/activate_package_screen.dart`
- `lib/features/staff/domain/gym_staff_summary.dart`
- `lib/features/staff/application/staff_providers.dart`
- `lib/features/staff/application/create_staff_service.dart`
- `lib/features/staff/presentation/staff_screen.dart`
- `lib/features/staff/presentation/create_staff_screen.dart`
- `lib/features/dashboard/domain/owner_analytics_models.dart`
- `lib/features/dashboard/application/dashboard_providers.dart`
- `lib/features/dashboard/presentation/dashboard_screen.dart`
- `lib/features/clients/application/client_insights_providers.dart`
- `lib/features/clients/presentation/client_insights_card.dart`
- `lib/features/bar/application/bar_actions_service.dart`
- `lib/features/bar/application/bar_providers.dart`
- `lib/features/bar/presentation/bar_admin_screen.dart`
- `lib/features/bar/presentation/bar_menu_screen.dart`
- `lib/features/bar/presentation/bar_pos_screen.dart`
- `lib/core/widgets/app_shell_scaffold.dart`
- `lib/core/routing/app_router.dart`

## 4. Samsung Runtime Verification

Device visibility:

- `adb devices -l`: PASS
- `flutter devices`: PASS
- Samsung device id: `RFCY706YLXD`
- Device: `SM S9210`
- Android version: 15 / API 35

Already live-verified on Samsung:

- app launch
- `Firebase.initializeApp`
- FirebaseAuth / Firestore / Functions client creation
- real owner-account login
- exact `users/{uid}` resolution
- exact `gyms/{gymId}/users/{uid}` resolution
- exact `gyms/{gymId}` resolution
- logout back to unauthenticated gate

Additionally live-verified in this pass:

- register via `createUserWithEmailAndPassword`
- onboarding route transition into `Create gym`
- real `createGymAndUser` submission
- post-onboarding route transition into `Verify email`

Live onboarding evidence:

- account created: `codexmobile202604050043@example.com`
- onboarding payload entered on Samsung:
  - `firstName=Codex`
  - `lastName=Mobile`
  - `phone=+998 90 123 45 67`
  - `name=CodexMobileQA20260405`
  - `city=Tashkent`
- resulting screen after submit:
  - `Verify email`
  - `Email/password login succeeded, but codexmobile202604050043@example.com must be verified before entering the app.`

Interpretation:

- Because bootstrap checks onboarding completeness before the email-verification gate, landing on `Verify email` is strong evidence that the onboarding callable completed and the app no longer considers the session onboarding-incomplete.

## 5. Evidence

Contract discovery evidence:

- `docs/mobile_contract_map.md`
- `docs/mobile_auth_bootstrap_audit.md`
- `docs/mobile_auth_contract_blockers.md`

Samsung evidence from prior live auth pass:

- `build/mobile_allclubs_recovery_check.png`
- `build/mobile_allclubs_login_clean.png`
- `build/mobile_live_after_submit.png`
- `build/mobile_live_authenticated_scrolled.png`
- `build/mobile_live_after_logout.png`

Samsung evidence from live onboarding pass:

- `build/mobile_onboarding_after_register.png`
- `build/mobile_onboarding_after_create_gym.png`
- `build/mobile_clients_screen_after_tap.png`
- `build/mobile_clients_rezone_final.png`

Local verification from this implementation pass:

- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build apk --debug`: PASS
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS
- owner bar-admin render tests: PASS
  - `renders the owner-only bar admin categories content`
  - `renders the owner-only bar admin products content`
  - `renders the owner-only bar admin incoming content`
- owner bar-pos render test: PASS
  - `renders the bar POS client, products, cart, and history`

Additional Samsung verification from the client-detail pass:

- Rezone owner session restored successfully
- `Clients` route still opens successfully
- tapping a real client row now opens `Client profile`
- direct client-doc profile fields render on Samsung
- subscription summary now renders successfully after aligning mobile with the actual working web runtime contract
- session summary renders successfully
- verified live with client `SHOXRUX KOMILOV`
- observed values included:
  - phone: `882107888`
  - gender: `male`
  - subscription status: `expired`
  - package: `1 kunlik`
  - session summary: `No session documents were returned for this client.`

Supporting evidence:

- `build/mobile_client_detail_index_blocker.png`
- `build/mobile_client_detail_live.png`

Local verification from the sessions implementation pass:

- `flutter analyze`: PASS
- `flutter test`: PASS
- authenticated shell now exposes `Open sessions`
- sessions route opens in widget tests
- session cards render real fields such as client name, package, staff, and online state

Samsung verification from the sessions pass:

- owner session restored successfully
- authenticated shell rendered a new `Sessions` card
- `Open sessions` opened the real sessions route for `Rezone`
- Samsung showed:
  - `5 sessions`
  - `1 active`
  - `4 closed`
- visible live row values included:
  - locker `22`
  - check-in `09:17`
  - status field `active`
  - online state `Online`

Supporting evidence:

- `build/mobile_sessions_live.png`

Local verification from the client-finance pass:

- `flutter analyze`: PASS
- `flutter test`: PASS
- client detail now renders a read-only finance summary card in widget tests
- linked payment rows are rendered in widget tests

Samsung verification from the client-finance pass:

- owner session restored successfully
- `Clients` opened successfully for `Rezone`
- `SHOXRUX KOMILOV` detail opened successfully
- `Finance summary` card rendered successfully on Samsung
- visible finance values included:
  - package price `40000`
  - paid amount `0`
  - debt `40000`
  - overpayment `0`
  - remaining `40000`
  - linked payments `0`

Supporting evidence:

- `build/mobile_client_finance_live.png`
- `build/mobile_client_finance_live_details.png`

Samsung verification from the staff pass:

- owner session restored successfully
- authenticated shell rendered a new `Staff` card
- `Open staff` opened the real owner-only route for `Rezone`
- Samsung showed:
  - `1 staff`
  - `1 active`
- visible live row values included:
  - `Jafarali Turaev`
  - `997034444`
  - `Staff`
  - `Active`

Supporting evidence:

- `build/mobile_staff_live_final.png`

Samsung verification from the create-staff pass:

- owner session restored successfully
- `Create staff` opened the owner-only callable route
- mobile submitted the exact audited callable contract on Samsung
- the live staff list updated immediately after submit
- visible updated values included:
  - `2 staff`
  - `2 active`
  - `Codex Staff QA`
  - `998901234568`

Supporting evidence:

- `build/mobile_create_staff_reopen.png`
- `build/mobile_create_staff_result.png`

Samsung verification from the first client-write slice:

- owner session restored successfully
- `Clients` still opens successfully
- the new `New client` button is visible on Samsung
- tapping `New client` opens the real `Create client` route
- the live route rendered the expected production-contract fields:
  - `First name`
  - `Last name`
  - `Phone`
  - `Gender`
  - `Birth date`
  - `Note`

Important truth for this pass:

- code for `createClient`, `bindClientCard`, `removeClientCard`, `startSession`, and `endSession` is implemented
- the exact write contracts were discovered from `D:\agentallclubs`
- Samsung now has clean live proof for `createClient`, `bindClientCard`, `removeClientCard`, `startSession`, and `endSession`
- Samsung now also has clean live proof for Android photo-picker selection plus photo-backed `createClient`

Supporting evidence:

- `build/mobile_create_client_and_bind_card_list.png`
- `build/mobile_create_client_and_bind_card_list.xml`
- `build/mobile_bind_card_success.png`
- `build/mobile_bind_card_success.xml`

Samsung verification from the photo-backed create-client pass:

- owner session restored successfully
- `New client` opened the real `Create client` route
- `Upload photo` opened the Android photo picker
- a real image was selected and the form returned with:
  - `scaled_4529.png`
  - `Replace photo`
  - `Remove photo`
- submit succeeded and mobile navigated directly into `Client profile`
- the created disposable client showed:
  - name `PhotoQA3Proofe998901234581 Last3998901234582`
  - phone `998901234583`
  - clientId `3GHyU7rOlkotvzTCUp3n`

Supporting evidence:

- `build/photo_picker.png`
- `build/window_dump_photo_picker.xml`
- `build/create_client_with_photo.png`
- `build/window_dump_create_client_with_photo.xml`
- `build/create_client_photo_submit_ready.png`
- `build/window_dump_create_client_photo_submit_ready.xml`
- `build/create_client_photo_result.png`
- `build/window_dump_create_client_photo_result.xml`

Samsung verification from the analytics pass:

- owner session restored successfully
- tapping `Stats` opened the owner-only analytics route
- the live loading state rendered:
  - `Loading the last 30 days through getOwnerAnalytics...`
- after the callable sequence completed, Samsung showed:
  - date `2026-04-06`
  - revenue `40000`
  - sessions `1`
  - active clients `1`
  - new clients `1`
- the same screen showed owned gym `Rezone`
- disposable client `ali vs` detail opened successfully
- the live `Client insights` card rendered through `getClientInsights`
- visible live client-insights values included:
  - `Last 30 visits = 2`
  - `Previous 30 = 0`
  - `Trend = up (+2)`
  - `Visits / week = 0.50`
  - `Inactive days = 0`
  - `Churn risk = low`
  - `Lifetime value = 120000`
  - `Last visit = 2026-04-06 10:25`
  - `No backend smart alerts were returned.`

Supporting evidence:

- `build/mobile_stats_open.png`
- `build/mobile_stats_after_wait.png`
- `build/mobile_client_insights_scroll4.png`
- `build/mobile_client_insights_scroll5.png`
- `build/mobile_client_insights_scroll6.png`
- `build/mobile_client_insights_scroll7.png`

Samsung verification from the package and session-action pass:

- disposable client `ali vs` was used as the safest live test target in `Rezone`
- `Activate package` opened successfully from client detail
- the real package list rendered from `gyms/{gymId}/packages`
- the first live sale exposed a source-of-truth mismatch:
  - mobile used a local-date default
  - the working web drawer uses `new Date().toISOString().split("T")[0]`
  - the subscription landed as `scheduled`
- mobile was corrected to mirror the web UTC default exactly
- after the fix, the route reopened with `Start date = 2026-04-05`
- real package sale PASS:
  - `createSubscription` submit succeeded
  - client detail showed `Package state: 1 kunlik`
  - client detail showed `Session state: Ready for check-in`
- real start session PASS:
  - `Give key` dialog opened
  - locker `22` was entered
  - client detail showed `Active session in progress`
  - session summary showed `Active now` and `Locker 22`
- real end session PASS:
  - confirmation dialog opened and submitted
  - client detail showed `ali vs session ended.`
  - the one-visit package was consumed and the action card returned to no active package

Supporting evidence:

- `build/mobile_client_end_session_live.png`
- `build/mobile_client_end_session_live.xml`

Samsung verification from the create-client and bind-card closeout pass:

- owner session restored successfully
- `Clients` route still opens successfully for `Rezone`
- the live clients count increased to `210 clients`
- `New client` opened the real `Create client` route
- the minimal production payload submitted successfully:
  - `firstName = aa`
  - `lastName = bb`
  - `phone = 668686869`
  - `gender = male`
- mobile navigated directly into the created client profile with:
  - `full name = aa bb`
  - `clientId = lqdxX4xgFDo2bTu4RT3u`
  - `phone = 668686869`
- `Bind card` then opened for the newly created client
- mobile autofocus was added to the card field so the editor becomes immediately usable on device
- numeric card id `406001` was saved successfully
- the live clients list then showed the new row with:
  - `aa bb`
  - `668686869`
  - `Card 406001`

Supporting evidence:

- `build/mobile_create_client_and_bind_card_list.png`
- `build/mobile_create_client_and_bind_card_list.xml`
- `build/mobile_bind_card_success.png`
- `build/mobile_bind_card_success.xml`

## 6. Exact Blockers

1. `updateClient` is still blocked because `D:\agentallclubs\src\firebase.js` exposes a wrapper, but the visible backend export list contains no real `updateClient` callable.
2. `updateProfile` is also blocked because `D:\agentallclubs\src\firebase.js` exposes a wrapper, but the visible backend export list contains no real `updateProfile` callable.
3. Samsung adb/device stability is still the main blocker for the remaining narrow edge-case proofs.
4. Local `flutter run` debug attach remains flaky because of the known `adb forward` / `AdbWinApi.dll.dat` issue.
5. The live onboarding and disposable client test records now exist in production data and should be kept or cleaned up intentionally later.
6. `syncSuperAdminAccess` and `clearOnboardingLock` are now wired in mobile code, but no Samsung proof was performed in this pass because no live super-admin login or onboarding-lock recovery scenario was exercised.
7. `getGymInvites` still returns `Exception: INTERNAL`, so invite history plus `resendInvite` / `cancelInvite` remain blocked by backend behavior rather than mobile wiring.

## 8. First Read-Only Module Status

Clients module:

- Status: PASS
- Source-of-truth contract:
  - `gyms/{gymId}/clients`
  - `where("isArchived", "==", false)`
  - `orderBy("createdAt", "desc")`
  - access for `owner` / `staff` with gym context
- Samsung verification:
  - empty-state verified for the newly created `test` gym
  - populated-state verified for `Rezone`
  - visible count on Samsung: `208 clients`
  - tapping a real client now opens the new read-only detail route
  - direct client-doc profile fields render successfully
  - subscription summary renders successfully
  - session summary renders successfully, including truthful empty-state when no session docs exist

Supporting audit:

- `docs/mobile_clients_module_audit.md`

Sessions module:

- Status: PASS
- Source-of-truth contract:
  - `gyms/{gymId}/sessions`
  - `orderBy("createdAt", "desc")`
  - `limit(500)`
  - optional in-memory `clientId` route filter
  - access for `owner` / `staff` with gym context

Supporting audit:

- `docs/mobile_sessions_module_audit.md`

Filtered client sessions handoff:

- Status: PASS
- Source-of-truth contract:
  - route `/app/sessions?clientId=...`
  - same `gyms/{gymId}/sessions` read stream
  - same `orderBy("createdAt", "desc")`
  - same `limit(500)`
  - exact in-memory filter by `clientId`
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
  - regression test now proves the filtered client route renders inside the shared shell body
- Android proof status:
  - direct filtered route opened on Samsung with clientId `IMJIT6QfN87ZUDFQcj5b`
  - route stayed inside the fixed shell with:
    - header `AllClubs Mobile`
    - selected bottom tab `Sessions`
  - Samsung rendered:
    - `Client sessions`
    - `Back to client`
    - `Client filter`
    - `ali vs`
    - `Rezone`
    - `2 sessions`
    - `0 active`
    - `2 closed`
  - filtered row content rendered instead of the previous blank body
  - supporting evidence:
    - `build/direct_filtered_sessions_route.png`
    - `build/direct_filtered_sessions_scrolled.png`
    - `build/direct_filtered_sessions_rows.png`

Client finance summary:

- Status: PASS
- Source-of-truth contract:
  - `gyms/{gymId}/transactions`
  - `gyms/{gymId}/financeTransactions`
  - merged in memory and sorted by `createdAt desc`
  - subscription enrichment via `gyms/{gymId}/subscriptions`
  - client filtering by `clientId`
  - read-only selected-subscription payment summary
- Samsung verification:
  - verified inside `Client profile` for `SHOXRUX KOMILOV`
  - visible values included `package price 40000`, `paid amount 0`, `debt 40000`, `overpayment 0`, `remaining 40000`, `linked payments 0`
  - finance write loop is now also Samsung-verified on disposable client `ali vs`
  - `Activate package` PASS to create a fresh linked payment row
  - resulting finance summary showed:
    - `Linked payments = 1`
    - `cash`
    - `40000`
    - `2026-04-07 17:03`
  - `Delete payment` PASS:
    - exact confirm dialog opened
    - Samsung then showed `Payment reversed.`
    - finance snapshot changed to:
      - `Paid amount = 0`
      - `Debt = 40000`
      - `Linked payments = 2`
      - reversing row `cash -40000`
  - `Restore payment` PASS:
    - exact confirm dialog opened
    - Samsung then showed `Payment restored.`
    - finance snapshot changed to:
      - `Paid amount = 40000`
      - `Debt = 0`
      - `Linked payments = 3`
      - newest compensating row `cash 40000`

Supporting audit:

- `docs/mobile_client_finance_audit.md`

Staff module:

- Status: PASS
- Source-of-truth contract:
  - route `/app/staffs`
  - owner only via `RequireOwner`
  - realtime stream from `gyms/{gymId}/users`
  - local in-memory filter `role == "staff"`
- Samsung verification:
  - verified in `Rezone`
  - visible values included `1 staff`, `1 active`, `Jafarali Turaev`, `997034444`

Supporting audit:

- `docs/mobile_staff_module_audit.md`

Staff management actions:

- Status: PASS
- Source-of-truth contract:
  - callable `updateStaff`
  - callable `deactivateStaff`
  - callable `removeStaff`
  - callable `getActiveStaff`
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
  - `flutter build apk --debug`: PASS
  - `adb install -r ...app-debug.apk`: PASS
- Android proof status:
  - updated APK installed on Samsung
  - Samsung proof for deactivate PASS
  - Samsung proof for reactivate PASS
  - Samsung proof for remove PASS
  - Samsung proof for edit PASS
  - owner-side `Edit staff` dialog opened on Samsung
  - disposable rename `CodexStaffQA2 -> CodexStaffQA2B` submitted successfully
  - Samsung returned inline success `Staff updated.`
  - the live row reflected the updated name `CodexStaffQA2B`
  - the live staff list now uses hybrid sync:
    - realtime membership stream from `gyms/{gymId}/users`
    - active-state refresh through exact `getActiveStaff`
  - supporting evidence:
    - `build/staff_edit_form_open.png`
    - `build/staff_edit_name_appended.png`
    - `build/staff_edit_save_result_success.png`

Onboarding recovery utility:

- Status: PARTIAL
- Source-of-truth contract:
  - callable `clearOnboardingLock`
  - request payload `{ uid }`
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
  - `flutter build apk --debug`: PASS
  - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS
- Android proof status:
  - recovery entry is wired into the create-gym error state
  - clean Samsung proof for a real stuck-onboarding recovery is still pending

Daily stats callable:

- Status: PASS
- Source-of-truth contract:
  - callable `getGymDailyStats`
  - request payload `{ date }`
  - authenticated owner or staff with resolved gym
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
  - `flutter build apk --debug`: PASS
  - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS
- Android proof status:
  - updated APK installed on Samsung
  - new build cold-launched successfully
  - Samsung `Stats` route first showed `Loading today through getGymDailyStats...`
  - after waiting, Samsung showed the exact callable values for `Rezone`:
    - `date = 2026-04-07`
    - `revenue = 0`
    - `sessions = 0`
    - `active clients = 1`
    - `new clients = 0`
  - supporting evidence:
    - `build/mobile_daily_stats_wait_20s.png`
    - `build/window_dump_stats_20s.xml`

Delete-transaction utility:

- Status: PASS
- Source-of-truth contract:
  - callable `deleteTransaction`
  - request payload `{ transactionId }`
  - owner only
  - applies only to `gyms/{gymId}/transactions`
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
  - `flutter build apk --debug`: PASS
  - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS
- Android proof status:
  - owner-only delete entry is wired into the finance list
  - mobile only exposes delete for entries sourced from `transactions`
  - Samsung confirmation dialog opened with the exact target transaction id
  - Samsung submit returned the success state:
    - `Finance`
    - `Transaction deleted.`
  - the live finance totals changed from `17 entries / 12 payments / 9144000 tracked`
    to `16 entries / 11 payments / 9104000 tracked`
  - supporting evidence:
    - `build/mobile_delete_transaction_confirm.png`
    - `build/mobile_delete_transaction_result.png`

Create-staff callable:

- Status: PASS
- Source-of-truth contract:
  - callable `createStaff`
  - owner only
  - payload `{ email, password, fullName, phone }`
  - backend creates real auth user plus `users/{uid}` and `gyms/{gymId}/users/{uid}`
- Samsung verification:
  - callable submit PASS
  - live staff list update PASS
  - second disposable staff payload PASS:
    - `fullName=CodexStaffQA2`
    - `phone=998901234569`
    - `email=codexstaff20260405b@gmail.com`
  - real staff sign-in PASS
  - staff shell gate PASS
  - staff access to `Clients` PASS
  - staff access to `Sessions` PASS

Supporting evidence:

- `build/mobile_create_staff_after_submit_simple.png`
- `build/mobile_staff_signin_result_simple.png`
- `build/mobile_staff_shell_after_scroll3.png`
- `build/mobile_staff_sessions_open2.png`
- `build/window_dump_staff_clients_open.xml`

Client write slice:

- Status: PASS
- Source-of-truth contract:
  - callable `createClient` with the flat routed-page payload
  - transaction-based `bindClientCard` / `removeClientCard`
  - callable `startSession`
  - callable `endSession`
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
- Samsung verification:
  - `Clients` route still opens
  - `New client` button visible
  - `Create client` route visible
  - `createClient` PASS with live created client `aa bb`
  - `bindClientCard` PASS with live card `406001`
  - `removeClientCard` PASS after the action-card lifecycle fix
  - `startSession` PASS
  - `endSession` PASS

Supporting audit:

- `docs/mobile_clients_module_audit.md`

Packages sale slice:

- Status: PASS
- Source-of-truth contract:
  - `gyms/{gymId}/packages`
  - exact sale callable `createSubscription`
  - payment amounts `{ cash, terminal, click, debt }`
  - UTC-based default start date via `new Date().toISOString().split("T")[0]`
- Samsung verification:
  - `Activate package` PASS
  - package sale PASS after UTC-default alignment
  - package state became active enough for check-in and then was consumed by the completed session

Supporting audit:

- `docs/mobile_packages_module_audit.md`

Package admin slice:

- Status: PASS
- Source-of-truth contract:
  - callable `createPackage`
  - callable `updatePackage`
  - callable `deletePackage`
  - active templates from `gyms/{gymId}/packages`
  - owner-only create/edit/delete
  - soft archive on delete
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
  - `flutter build apk --debug`: PASS
  - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS
- Android proof status:
  - owner session opened `Packages` successfully
  - Samsung showed `9 templates`
  - `createPackage` PASS with disposable `CodexPkg407A`
  - Samsung returned to `Packages` with `10 templates`
  - the original modal edit path exposed a Samsung blank-body bug
  - mobile was corrected to use a full-screen edit route
  - `updatePackage` PASS with disposable rename `CodexPkg407A -> CodexPkg407AB`
  - `deletePackage` PASS with archive confirmation
  - Samsung returned to `Packages` with:
    - `9 templates`
    - status `CodexPkg407AB archived.`
  - owner-only subscription status actions are now Samsung-verified on disposable client `ali vs`
  - `updateSubscriptionStartDate` PASS:
    - Android date picker opened from `Edit start date`
    - date changed to `2026-04-08`
    - inline status `Subscription start date updated.`
  - `deactivateSubscription` PASS:
    - confirmation dialog opened
    - inline status `Subscription deactivated.`
    - action state switched to `Activate`
  - `activateSubscription` PASS:
    - confirmation dialog opened
    - inline status `Subscription activated.`
    - action state switched back to `Deactivate`
  - `cancelSubscription` PASS:
    - confirmation dialog opened
    - inline status `Subscription cancelled.`
  - runtime nuance:
    - the subscription card explicitly says `Showing the most relevant record from 4 matching subscriptions.`
    - after state transitions the rendered summary can switch which matching record is surfaced, so the inline success state is the strongest proof of the callable result
  - supporting evidence:
    - `build/package_create_result.png`
    - `build/package_edit_route_open.png`
    - `build/package_update_result.png`
    - `build/package_delete_confirm_retry.png`
    - `build/package_delete_result.png`
    - `build/ali_edit_start_date_result.png`
    - `build/ali_deactivate_result_success.png`
    - `build/ali_activate_via_update_result.png`
    - `build/ali_cancel_subscription_result.png`

Bar admin slice:

- Status: PARTIAL
- Source-of-truth contract:
  - `gyms/{gymId}/barCategories`
  - `gyms/{gymId}/barProducts`
  - `gyms/{gymId}/barIncoming`
  - callable `holdCheck`
  - owner-only admin write actions
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
  - `flutter build apk --debug`: PASS
  - `adb install -r ...app-debug.apk`: PASS
- Android proof status:
  - a newer local debug APK is built after the latest `Bar POS` guard fix
  - `POS Menu` is Samsung-verified and showed:
    - `Rezone`
    - `1 active POS clients`
    - `Guest POS available`
    - active-session launcher row with locker `22`
  - guest POS route is now Samsung-verified:
    - `Open guest POS` launcher PASS
    - guest route header `Guest POS`
    - guest contract card rendered
    - exact disposable guest draft created through `createCheck(null, null)`
    - returned guest draft id `c2BqSRtngcjsLW8MpNKQ`
    - guest `addItem` PASS for `ide cofee`
    - stock changed `12 -> 11`
    - `Current check` card rendered for the guest draft
    - guest `holdCheck` PASS
    - after hold, `Current check` returned to `No draft bar check is open...`
    - guest `voidCheck` PASS
    - after void, the disposable guest draft cleared and stock rolled back `9 -> 10`
    - guest `payCheck` PASS
    - after payment, the disposable guest draft cleared while stock remained `9`
  - `Bar admin` route is Samsung-verified and showed:
    - title `Bar admin`
    - section chips `Categories / Products / Incoming`
    - category create form
    - existing category cards with `Edit` and `Delete`
  - Samsung live proof now includes:
    - `createBarCategory` PASS
    - disposable category `CodexCat410`
    - success state `Category created.`
    - `deleteBarCategory` PASS
    - success state `Category archived.`
    - `updateBarCategory` PASS
    - disposable rename `CodexCat411 -> CodexCat411B`
    - success state `Category updated.`
    - cleanup archive PASS for `CodexCat411B`
    - `createBarProduct` PASS
    - disposable product `CodexDrink410`
    - success state `Product created.`
    - `updateBarProduct` PASS
    - disposable rename `CodexSweet413 -> CodexSweet413B`
    - success state `Product updated.`
    - `deleteBarProduct` PASS
    - success state `Product archived.`
    - `createBarIncoming` PASS
    - disposable invoice `INC-KPMNME`
    - success state `Incoming invoice saved.`
    - `deleteBarIncoming` PASS
    - success state `Incoming invoice deleted.`
  - the inner `Bar POS` route is now Samsung-verified:
    - title `Bar POS`
    - current session card
    - category chips
    - product card
    - current-check card
    - debt card
    - history card
  - Samsung live proofs now include:
    - `addItem` PASS
    - `holdCheck` PASS
    - `checkClientDebt` PASS
    - `voidCheck` PASS
    - `payCheck` PASS
    - `refundCheck` PASS
  - observed live values included:
    - session client `Navroz muhammedov`
    - phone `917225522`
    - draft check `0t0YaO5D2T4ddiSRv4k9`
    - product `ide cofee`
    - price `20000 so'm`
    - stock `14 -> 13 -> 12 -> 13`
    - held debt `44000 so'm across 2 unpaid checks`
    - paid disposable check `jmpIVMjhO4GqweIEcYwj`
    - refunded disposable check `jmpIVMjhO4GqweIEcYwj`
  - remaining Samsung gaps for this slice:
    - keyboard-stable admin text-entry/edit path on Samsung
    - the previous Samsung `BOTTOM OVERFLOWED BY 40 PIXELS` category-input bug is now verified as fixed
    - no guest-only settlement blockers remain in the bar slice
  - supporting evidence:
    - `build/guest_pos_menu_open.png`
    - `build/guest_pos_screen_open.png`
    - `build/guest_pos_after_add_wait20.png`
    - `build/guest_pos_current_check_visible.png`
    - `build/guest_pos_after_hold.png`
    - `build/guest_void_result.png`
    - `build/guest_pay_dialog_open_real.png`
    - `build/guest_pay_result.png`
    - `build/bar_admin_live_after_render_fix.png`
    - `build/bar_admin_after_add_410_retry.png`
    - `build/bar_category_update_success_retry.png`
    - `build/bar_category_411b_delete_success.png`
    - `build/bar_product_after_save.png`
    - `build/bar_product_after_scroll.png`
    - `build/bar_update_product_name_appended.png`
    - `build/bar_update_product_save_result.png`
    - `build/bar_delete_product_confirm.png`
    - `build/bar_delete_product_result_retry.png`
    - `build/bar_incoming_saved_success.png`
    - `build/bar_incoming_history_delete_visible.png`
    - `build/bar_incoming_delete_success.png`
    - `build/bar_category_delete_success.png`
    - `build/bar_pos_menu_after_fix.png`
    - `build/bar_pos_live_after_fix.png`
    - `build/bar_pos_after_add_wait12.png`
    - `build/bar_pos_scrolled_to_cart.png`
    - `build/bar_pos_after_hold.png`
    - `build/bar_pos_after_check_debt.png`
    - `build/bar_pos_refund_button_visible.png`
    - `build/bar_pos_void_success.png`
    - `build/bar_pay_dialog_open_retry.png`
    - `build/bar_pay_success.png`
    - `build/bar_refund_confirm_dialog.png`
    - `build/bar_refund_success.png`
    - `build/bar_admin_category_focus_after_fix.png`
    - `build/window_dump_bar_admin_category_focus_after_fix.xml`

Supporting audit:

- `docs/mobile_bar_module_audit.md`

Dashboard module:

- Status: PASS
- Source-of-truth contract:
  - callable `getOwnerAnalytics`
  - request payload `{ date }`
  - owner-only access
  - response `summary` plus per-gym `gyms[]`
- Samsung verification:
  - verified on `Stats`
  - latest visible values:
    - date `2026-04-06`
    - revenue `40000`
    - sessions `1`
    - active clients `1`
    - new clients `1`
    - owned gym `Rezone`

Supporting audit:

- `docs/mobile_dashboard_module_audit.md`

Invites module:

- Status: PARTIAL
- Source-of-truth contract:
  - callable `sendInvite`
  - callable `cancelInvite`
  - callable `resendInvite`
  - callable `getGymInvites`
  - callable `validateInviteToken`
  - callable `acceptInvite`
  - owner route `/app/staffs/invites`
  - public route `/accept-invite?token=...`
  - exact accept flow:
    - `validateInviteToken`
    - `createUserWithEmailAndPassword`
    - callable `acceptInvite`
- Local verification:
  - `flutter analyze`: PASS
  - `flutter test`: PASS
  - `flutter build apk --debug`: PASS
  - Android proof status:
    - Samsung became visible and the updated APK was installed
    - owner session opened `Staff invites` successfully
    - live invite form opened successfully
    - `sendInvite` PASS on Samsung:
    - success card text `Invite created successfully.`
    - returned invite token `7IjxlNQ6pMPi0uk4N0hv`
    - supporting evidence `build/mobile_invites_send_success.png`
    - after surfacing callable failures instead of silently returning `[]`, `getGymInvites` now shows the exact Samsung error:
      - `Exception: INTERNAL`
    - supporting evidence `build/mobile_invites_internal_error.png`
  - direct token-route acceptance is now Samsung-verified:
    - app data was cleared so the route could open in an unauthenticated state
    - `/accept-invite?token=7IjxlNQ6pMPi0uk4N0hv` opened successfully on Samsung
    - Samsung rendered:
      - `Accept staff invite`
      - `codexinvite20260406a@gmail.com`
      - `staff`
      - `Di7qKRDQvrfSLZJnWZ1y`
      - prefilled name `CodexInviteQA`
    - disposable password used:
      - `Codex4777`
    - keyboard submit completed the exact flow:
      - `validateInviteToken`
      - `createUserWithEmailAndPassword`
      - callable `acceptInvite`
    - final Samsung result:
      - routed into `Verify email`
      - visible text:
        - `Email/password login succeeded, but codexinvite20260406a@gmail.com must be verified before entering the app.`
    - supporting evidence:
      - `build/accept_invite_open.png`
      - `build/accept_invite_submit_result.png`
  - because invite-history is blocked by that backend-side callable failure, only `resendInvite` and `cancelInvite` remain open

Supporting audit:

- `docs/mobile_invites_module_audit.md`

## 7. Safe Next Actions

1. Keep DB shape unchanged and continue only from the working web source-of-truth.
2. Keep DB/backend unchanged and treat `getGymInvites -> Exception: INTERNAL` as the current live invite blocker.
3. Keep `acceptInvite` closed as PASS through the direct token route until deep-link handling is added later.
4. Continue Samsung verification for the next remaining mobile-write categories while the invite-history callable blocker stands.
5. Live-verify photo upload on Samsung with a disposable client.
6. Live-verify `archiveClient` on Samsung with a disposable client.
7. Re-open `Bar POS` on Samsung and isolate whether the remaining blocker is device DNS/runtime only or a route-level rendering issue.
8. Live-verify the new `getGymDailyStats` card on Samsung for a real staff session.
9. Keep `updateClient` blocked until the real backend callable body becomes visible in source-of-truth.
