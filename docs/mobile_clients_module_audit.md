# Mobile Clients Module Audit

Status: Clients read flows are Samsung-verified; create-client, photo-backed create-client, archive action, bind-card, package sale, and session start/end are Samsung-verified
Audit date: 2026-04-07
Workspace: `D:\mobileallclubs`

## 1. Exact Source Of Truth

Working web repo:

- `D:\agentallclubs — копия`

Audited files:

- `D:\agentallclubs — копия\src\services\clientService.js`
- `D:\agentallclubs — копия\src\modules\clients\domain\ClientsContext.jsx`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClients.js`
- `D:\agentallclubs — копия\src\pages\clients\ClientsPage.jsx`
- `D:\agentallclubs — копия\src\modules\clients\ui\ClientsTable.jsx`
- `D:\agentallclubs — копия\src\components\RequireRole.jsx`
- `D:\agentallclubs — копия\src\pages\clients\ClientProfilePage.jsx`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientProfileSummary.js`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientAttendance.js`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientPersonalInfo.jsx`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientSubscriptionCard.jsx`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientLiveStatusCard.jsx`
- `D:\agentallclubs — копия\src\services\subscriptionService.js`
- `D:\agentallclubs — копия\src\services\sessionService.js`
- `D:\agentallclubs — копия\src\context\transaction\TransactionContext.jsx`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientFinance.js`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientFinancePanel.jsx`
- `D:\agentallclubs\src\pages\clients\CreateClient.jsx`
- `D:\agentallclubs\src\services\clientService.js`
- `D:\agentallclubs\functions\index.js`

## 2. Real Clients Contract

Collection path:

- `gyms/{gymId}/clients`

Exact read query:

- `where("isArchived", "==", false)`
- `orderBy("createdAt", "desc")`

Exact access rule:

- `owner` or `staff`
- gym context required

Exact fields rendered in the mobile list:

- `firstName`
- `lastName`
- `phone`
- `email`
- `image`
- `cardId`
- Firestore doc id as `id`

Exact detail contracts discovered from the working web app:

- client doc:
  - `gyms/{gymId}/clients/{clientId}`
- subscriptions runtime path:
  - stream `gyms/{gymId}/subscriptions`
  - `orderBy("createdAt", "desc")`
  - filter by `clientId` locally in the profile layer
- sessions runtime path:
  - stream `gyms/{gymId}/sessions`
  - `orderBy("createdAt", "desc")`
  - `limit(500)`
  - filter by `clientId` locally in the profile layer

Important runtime note:

- direct helper queries by `clientId` do exist in the web services
- the working profile page actually consumes the shared subscriptions/sessions contexts and filters locally
- mobile originally tried the helper-query shape, hit live Firestore index blockers, and was then corrected to match the real runtime contract

Exact detail fields rendered in mobile from the discovered contract:

- profile:
  - `firstName`
  - `lastName`
  - `phone`
  - `email`
  - `image`
  - `cardId`
  - `gender`
  - `age`
  - `type`
  - `lifetimeSpent`
  - `createdAt`
- subscriptions:
  - `status`
  - `packageSnapshot.name`
  - `packageSnapshot.duration`
  - `packageSnapshot.price`
  - `packageSnapshot.isUnlimited`
  - `visitLimit`
  - `remainingVisits`
  - `startDate`
  - `endDate`
- sessions:
  - `status`
  - `locker`
  - `startedAt`
  - `endedAt`
  - `createdAt`
- finance:
  - `packageSnapshot.price`
  - payment totals from linked transactions
  - debt
  - overpayment
  - remaining amount
  - payments list rows from merged transaction streams
- client insights:
  - `attendanceTrend.direction`
  - `attendanceTrend.delta`
  - `attendanceTrend.last30`
  - `attendanceTrend.previous30`
  - `visitFrequency.visitsPerWeek`
  - `inactiveDays`
  - `churnRisk`
  - `lifetimeValue`
  - `lastVisitAt`
  - `alerts[]`

## 3. What Was Implemented In Mobile

- real Firestore stream for `gyms/{gymId}/clients`
- exact `isArchived == false` filter
- exact `createdAt desc` ordering
- owner/staff plus gym-context access gate
- real read-only clients route
- real read-only client detail route
- real package-sale route using the exact `createSubscription` contract
- client-side search by name, phone, or email
- client detail personal info card
- client detail client-insights card backed by the exact `getClientInsights` callable
- client detail subscription summary card
- client detail finance summary card
- client detail live/session summary card
- real create-client route using the exact working page payload
- quick `Give key` and `End session` actions on the clients list
- client detail action card for `Bind card`, `Give key`, and `End session`
- transaction-based card bind/remove using the discovered production Firestore paths
- callable-based `startSession` / `endSession` wrappers
- Firebase Storage photo upload using the exact working web path shape:
  - `gyms/{gymId}/clients/{timestamp}-{uid}.{ext}`
- owner-only `archiveClient` callable wrapper and action
- empty, loading, and error states
- entry button from the authenticated shell into the clients route
- tap-through navigation from list row into client detail

Implementation files:

- `lib/features/clients/domain/client_summary.dart`
- `lib/features/clients/domain/client_detail_models.dart`
- `lib/features/clients/application/clients_providers.dart`
- `lib/features/clients/application/client_detail_providers.dart`
- `lib/features/clients/application/client_actions_service.dart`
- `lib/features/clients/application/client_insights_providers.dart`
- `lib/features/clients/presentation/clients_screen.dart`
- `lib/features/clients/presentation/client_insights_card.dart`
- `lib/features/clients/presentation/client_detail_screen.dart`
- `lib/features/clients/presentation/create_client_screen.dart`
- `lib/features/clients/presentation/start_session_dialog.dart`
- `lib/features/packages/domain/gym_package_summary.dart`
- `lib/features/packages/application/package_providers.dart`
- `lib/features/packages/application/subscription_sale_service.dart`
- `lib/features/packages/presentation/activate_package_screen.dart`
- `lib/features/finance/domain/gym_transaction_summary.dart`
- `lib/features/finance/application/transaction_providers.dart`
- `lib/features/auth/presentation/authenticated_shell_screen.dart`
- `lib/core/routing/app_router.dart`

## 4. What Was Verified On Samsung

Verified with the newly created `test` gym account:

- clients route opens successfully
- query executes successfully
- empty-state renders correctly when no active clients exist

Evidence:

- `build/mobile_clients_screen_after_tap.png`

Verified with the existing populated owner account:

- owner sign-in succeeds
- clients route opens successfully for gym `Rezone`
- live clients query returns populated production data
- Samsung screen showed `208 clients`
- visible returned rows included:
  - `SHOXRUX KOMILOV`
  - `Navroz muhammedov`
  - `Rushana Hasanova`

Evidence:

- `build/mobile_clients_rezone_final.png`

Additionally verified with the existing populated owner account on Samsung after the detail implementation:

- tapping a real client row now opens the new `Client profile` route
- verified live with client `SHOXRUX KOMILOV`
- profile screen rendered the real client doc fields, including:
  - full name: `SHOXRUX KOMILOV`
  - phone: `882107888`
  - email: `Unavailable`
  - card ID: `Unavailable`
  - gender: `male`
  - created: `2026-03-30 15:11`
- subscription summary rendered successfully with:
  - status: `expired`
  - package: `1 kunlik`
  - plan price: `40000`
  - plan duration: `1 days`
  - visits: `0 remaining of 1 (1 used)`
  - start date: `2026-02-03 00:00`
  - end date: `2026-02-04 00:00`
- session summary rendered truthfully with:
  - `No session documents were returned for this client.`

Interpretation:

- the new detail route, profile fields, and downstream summaries are all working on Samsung
- the mobile app is not guessing anything here; it now matches the actual working web runtime path
- the initial Firestore index blocker was caused by following helper queries instead of the real profile-runtime contract, and that mismatch is now fixed
- the new finance summary card is implemented from the audited transaction runtime contract and is now Samsung-verified in the live client detail flow

Evidence:

- `build/mobile_client_detail_index_blocker.png`
- `build/mobile_client_detail_live.png`
- `build/mobile_client_finance_live.png`
- `build/mobile_client_finance_live_details.png`

Additionally verified on Samsung after the first write slice implementation:

- owner session restored successfully
- `Clients` still opens successfully
- the new `New client` button is visible in the live clients route
- tapping `New client` opens the real `Create client` route on Samsung
- the write form renders the expected production-contract fields:
  - `First name`
  - `Last name`
  - `Phone`
  - `Gender`
  - `Birth date`
  - `Note`

Evidence:

- `build/mobile_write_flow_entry.png`
- `build/mobile_write_flow_clients.png`
- `build/mobile_write_flow_create_client_screen.png`

Local verification after the write-slice implementation:

- `flutter analyze`: PASS
- `flutter test`: PASS

Additionally verified on Samsung after wiring the real package-sale plus session-action flow:

- disposable client `ali vs` was used as the safest live test target
- `Activate package` opened successfully from client detail
- the real package list rendered from `gyms/{gymId}/packages`
- a first live sale exposed a source-of-truth mismatch:
  - mobile used a local-device default date
  - the working web app uses `new Date().toISOString().split("T")[0]`
  - the resulting subscription was created as `scheduled`
- mobile was corrected to mirror the web UTC default exactly
- after the fix, `Activate package` reopened with `Start date = 2026-04-05`
- the real `createSubscription` submit succeeded on Samsung
- client detail then showed:
  - `Package state: 1 kunlik`
  - `Session state: Ready for check-in`
- `Give key` opened the real start-session dialog
- locker `22` was entered and `Start session` succeeded
- the client detail flow then showed:
  - `Session state: Active session in progress`
  - `Current locker: 22`
  - `ali vs session started.`
- lower on the same screen, `Session summary` rendered:
  - `Live status: Active now`
  - `Locker 22`
- `End session` confirmation succeeded on Samsung
- the client detail flow then returned to:
  - `Package state: No active subscription found`
  - `Session state: No active package`
  - `ali vs session ended.`

Evidence:

- `build/mobile_client_end_session_live.png`
- `build/mobile_client_end_session_live.xml`

Additionally verified on Samsung after the create-client and bind-card closeout pass:

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

Evidence:

- `build/mobile_create_client_and_bind_card_list.png`
- `build/mobile_create_client_and_bind_card_list.xml`
- `build/mobile_bind_card_success.png`
- `build/mobile_bind_card_success.xml`

Additionally verified on Samsung after the analytics pass:

- owner session restored successfully
- header `Stats` route opened and loaded live owner analytics through `getOwnerAnalytics`
- Samsung showed exact latest owner summary values for `2026-04-06`:
  - revenue `40000`
  - sessions `1`
  - active clients `1`
  - new clients `1`
- the same screen showed owned gym row `Rezone`
- in `Clients`, disposable client `ali vs` detail opened successfully
- the new `Client insights` card loaded through `getClientInsights`
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

Evidence:

- `build/mobile_stats_open.png`
- `build/mobile_stats_after_wait.png`
- `build/mobile_client_insights_scroll4.png`
- `build/mobile_client_insights_scroll5.png`
- `build/mobile_client_insights_scroll6.png`
- `build/mobile_client_insights_scroll7.png`

Local verification after the photo-upload and archive pass:

- `flutter pub get`: PASS
- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build apk --debug`: PASS

Additionally verified on Samsung after the archive-client pass:

- disposable client `aa bb` was reopened from the live clients list
- the action card exposed the real `Archive client` button
- the confirmation dialog rendered the exact callable-backed copy:
  - `Archive aa bb?`
- submit succeeded and the route returned to the live clients list
- Samsung showed the active list count drop from `210 clients` to `209 clients`
- the archived `aa bb` row disappeared from the active list immediately

Evidence:

- `build/mobile_archive_client_confirm.png`
- `build/mobile_archive_client_result.png`
- `build/window_dump_archive_client_confirm.xml`
- `build/window_dump_archive_client_result.xml`

Additionally verified on Samsung after the photo-upload closeout pass:

- `New client` opened the real `Create client` route
- `Upload photo` opened the Android system photo picker
- a real photo was selected and the form returned with:
  - selected file name `scaled_4529.png`
  - `Replace photo`
  - `Remove photo`
- submit succeeded with the selected image attached
- mobile navigated directly into the created client profile
- the created disposable client showed:
  - full name `PhotoQA3Proofe998901234581 Last3998901234582`
  - clientId `3GHyU7rOlkotvzTCUp3n`
  - phone `998901234583`

Important runtime note:

- the unusual concatenated disposable name values came from `adb shell input text` automation while driving the Samsung keyboard, not from a different backend contract
- despite the noisy disposable text values, this pass cleanly proves the exact mobile flow:
  - Android photo picker selection
  - Firebase Storage upload using `gyms/{gymId}/clients/{timestamp}-{uid}.{ext}`
  - `createClient` submit with `image`
  - post-submit route transition into the created client profile

Evidence:

- `build/photo_picker.png`
- `build/window_dump_photo_picker.xml`
- `build/create_client_with_photo.png`
- `build/window_dump_create_client_with_photo.xml`
- `build/create_client_photo_submit_ready.png`
- `build/window_dump_create_client_photo_submit_ready.xml`
- `build/create_client_photo_result.png`
- `build/window_dump_create_client_photo_result.xml`

Important truth for this pass:

- the new photo upload wiring follows the exact working web create-client page contract
- the new archive action follows the exact backend callable contract
- Samsung device visibility stayed healthy during this pass
- the updated APK was installed successfully on Samsung
- archive submission is now cleanly Samsung-verified
- photo picker selection, Storage upload, and photo-backed create-client submit are now cleanly Samsung-verified

## 5. Safe Limits Kept

- No backend code changed
- No Firestore rules changed
- No indexes changed
- No schema changed
- No guessed collections used
- No DB paths or production contracts were changed
- No destructive bulk writes were performed
- The mobile create-card-session slice follows the exact discovered web contract

## 6. Exact Remaining Blockers

1. `updateClient` is still blocked because the web repo exposes a stale `updateClient` wrapper, but the visible backend export list contains no real `updateClient` callable body to follow safely.
2. `updateProfile` is also blocked for the same reason: `src/firebase.js` exposes a stale wrapper, but no backend `updateProfile` export is visible in source-of-truth.
3. Payment collection and richer subscription-management write flows beyond the audited package sale are not implemented yet.
4. `flutter run` debug attach is still flaky because of the local `adb forward` / `AdbWinApi.dll.dat` issue.

## 7. Safe Next Actions

1. Keep `updateClient` and `updateProfile` blocked until real backend exports become visible in source-of-truth.
2. Continue with the next daily write slice, most likely payment collection or richer subscription management, using `D:\agentallclubs` as the source-of-truth.
3. Clean up disposable photo-upload test data later if the team wants production-like data kept tidy.
