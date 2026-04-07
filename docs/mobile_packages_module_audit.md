# Mobile Packages Module Audit

Status: Package sale, sold-packages route parity, package-admin CRUD, and subscription status actions are Samsung-verified
Audit date: 2026-04-07
Workspace: `D:\mobileallclubs`

## 1. Exact Source Of Truth

Working web repo:

- `D:\agentallclubs`

Audited files:

- `D:\agentallclubs\src\modules\packages\domain\PackagesContext.jsx`
- `D:\agentallclubs\src\pages\packages\CreatePackage.jsx`
- `D:\agentallclubs\src\pages\packages\PackagesPage.jsx`
- `D:\agentallclubs\src\modules\packages\ui\EditPackageDrawer.jsx`
- `D:\agentallclubs\src\modules\packages\ui\DeletePackageModal.jsx`
- `D:\agentallclubs\src\modules\subscriptions\ui\ActivatePackageDrawer.jsx`
- `D:\agentallclubs\src\components\modals\PaymentModal.jsx`
- `D:\agentallclubs\src\services\subscriptionService.js`
- `D:\agentallclubs\src\firebase.js`
- `D:\agentallclubs\functions\index.js`

## 2. Real Packages Contract

Package read path:

- `gyms/{gymId}/packages`

Exact read query:

- `where("isArchived", "==", false)`
- `orderBy("createdAt", "desc")`

Exact fallback behavior:

- if the indexed query fails, the runtime falls back to `where("isArchived", "==", false)` and sorts locally

Exact package sale callable:

- `createSubscription`

Exact request payload:

- `clientId`
- `packageId`
- `startDate`
- `amounts`
- `comment`
- `replaceId`

Exact payment object shape:

- `cash`
- `terminal`
- `click`
- `debt`

Important source-of-truth nuance:

- the working web drawer defaults `startDate` with `new Date().toISOString().split("T")[0]`
- this is UTC-based
- mobile was corrected to mirror this exactly after Samsung showed a `scheduled` subscription caused by a local-date default mismatch

Exact package admin callables:

- `createPackage`
- `updatePackage`
- `deletePackage`

Exact package admin behavior:

- package templates stay under `gyms/{gymId}/packages`
- `/app/packages` shows package templates
- the working web `sold` tab is backed by `gyms/{gymId}/subscriptions`
- sold rows resolve client name/phone from either the subscription doc or the current clients context
- sold-row `Edit` uses `updateSubscriptionStartDate`
- sold-row `Replace` reuses `createSubscription` with `replaceId`
- `/app/packages/create` is owner only
- edit and delete actions are owner only
- delete is a soft archive, not a hard delete
- `visitLimit` stays locked to `duration + bonusDays`

## 3. What Was Implemented In Mobile

- realtime package stream from `gyms/{gymId}/packages`
- indexed query with local-sort fallback
- full-screen `Activate package` route
- exact payment method keys: `cash`, `terminal`, `click`, `debt`
- exact callable wrapper for `createSubscription`
- exact callable wrapper for `updateSubscription`
- exact owner-only subscription status actions:
  - activate
  - deactivate
  - cancel
- inline validation for balanced payment totals
- required comment when `debt > 0`
- safe route-back into client detail after submit
- UTC-based default request date aligned with the working web app
- exact owner-only `updateSubscriptionStartDate` action
- package templates tab now reads real docs from `gyms/{gymId}/packages`
- sold-packages tab now reads real docs from `gyms/{gymId}/subscriptions`
- sold rows now resolve client labels against the current mobile clients stream
- owner-only create-package route
- exact callable wrapper for `createPackage`
- exact callable wrapper for `updatePackage`
- exact callable wrapper for `deletePackage`
- owner-only edit/delete actions on the packages tab
- staff-visible read-only package-template list
- owner-only sold-row `Edit` action wired to the shared full-screen `Activate package` route in `editStartOnly` mode
- owner-only sold-row `Replace` action wired to the shared full-screen `Activate package` route with `replaceId`

Implementation files:

- `lib/features/packages/domain/gym_package_summary.dart`
- `lib/features/packages/application/package_actions_service.dart`
- `lib/features/packages/application/package_providers.dart`
- `lib/features/packages/application/subscription_sale_service.dart`
- `lib/features/packages/presentation/activate_package_screen.dart`
- `lib/features/packages/presentation/create_package_screen.dart`
- `lib/features/packages/presentation/packages_screen.dart`
- `lib/features/clients/presentation/client_detail_screen.dart`
- `lib/core/routing/app_router.dart`

## 4. What Was Verified On Samsung

Verified with disposable client `ali vs` in gym `Rezone`:

- `Activate package` opens from the real client detail action card
- the live package list renders real package docs, including:
  - `1 kunlik`
  - `Start (1 oylik)`
  - other long-duration packages
- a first live submit using the old local-date default created a real `scheduled` subscription
- after the UTC-default fix, the route opened with `Start date = 2026-04-05`, matching the working web contract
- a second live submit succeeded and returned to client detail with:
  - `Package state: 1 kunlik`
  - `Session state: Ready for check-in`
  - `Replace package` now visible
- exact owner-only subscription status actions are now Samsung-verified on the same disposable client:
  - `updateSubscriptionStartDate` PASS
  - `deactivateSubscription` PASS
  - `activateSubscription` PASS
  - `cancelSubscription` PASS
- live `Edit start date` opened the Android date picker, changed the start date to `2026-04-08`, and returned the inline success state:
  - `Subscription start date updated.`
  - rendered start date `2026-04-08 00:00`
- live `Deactivate` opened the exact confirmation dialog:
  - title `Deactivate subscription`
  - message `Deactivate 1 kunlik using the exact updateSubscription callable?`
  - after submit Samsung showed `Subscription deactivated.`
  - action state switched from `Deactivate` to `Activate`
- live `Activate` then opened the exact confirmation dialog:
  - title `Activate subscription`
  - message `Activate 1 kunlik using the exact updateSubscription callable?`
  - after submit Samsung showed `Subscription activated.`
  - action state switched back to `Deactivate`
- live `Cancel subscription` then opened the exact confirmation dialog:
  - title `Cancel subscription`
  - message `Mark 1 kunlik as cancelled using the exact updateSubscription callable?`
  - after submit Samsung showed `Subscription cancelled.`
- important runtime nuance:
  - the client detail screen intentionally says `Showing the most relevant record from 4 matching subscriptions.`
  - after state transitions, the summary card may switch which matching record is surfaced, so the inline success state is the strongest proof that the callable submit completed

Supporting evidence:

- `build/mobile_client_end_session_live.png`
- `build/mobile_client_end_session_live.xml`
- `build/ali_activate_payment_dialog.png`
- `build/ali_activate_after_select_scroll.png`
- `build/ali_activate_cash_selected.png`
- `build/ali_activate_confirm_section.png`
- `build/ali_package_sale_result.png`
- `build/ali_edit_start_date_dialog.png`
- `build/ali_edit_start_date_selected_8.png`
- `build/ali_edit_start_date_result.png`
- `build/ali_deactivate_confirm.png`
- `build/ali_deactivate_result_success.png`
- `build/ali_activate_via_update_confirm.png`
- `build/ali_activate_via_update_result.png`
- `build/ali_cancel_subscription_confirm.png`
- `build/ali_cancel_subscription_result.png`

Verified with disposable package template `CodexPkg407A` in gym `Rezone`:

- `Packages` tab opened successfully for the resolved owner session
- Samsung showed the live package-template summary:
  - `9 templates`
  - `0 freeze-enabled`
  - `9 time-restricted`
- `New package` opened the real owner-only create route
- `createPackage` PASS with the exact audited contract:
  - `name = CodexPkg407A`
  - `price = 12345`
  - `duration = 30`
  - `bonusDays = 0`
  - `gender = all`
  - `startTime = 00:00`
  - `endTime = 23:59`
- after submit Samsung returned to `Packages` and showed:
  - `10 templates`
  - live row `CodexPkg407A`
- the original modal edit sheet exposed a Samsung-only blank-body runtime bug
- mobile was corrected to use a full-screen edit route instead of the modal sheet
- `updatePackage` PASS after the route fix:
  - live route title `Edit package`
  - disposable rename `CodexPkg407A -> CodexPkg407AB`
  - after submit Samsung returned to `Packages` with row `CodexPkg407AB`
- `deletePackage` PASS:
  - confirmation dialog showed `Archive CodexPkg407AB? Active clients will not be affected.`
  - after submit Samsung showed:
    - `9 templates`
    - status `CodexPkg407AB archived.`
  - the disposable package row disappeared from the visible active-template list

Supporting evidence:

- `build/package_create_result.png`
- `build/package_edit_route_open.png`
- `build/package_edit_name_appended.png`
- `build/package_update_result.png`
- `build/package_delete_confirm_retry.png`
- `build/package_delete_result.png`

Local verification after the package-admin pass:

- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build apk --debug`: PASS
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS

Important truth for this pass:

- package admin create/update/delete now follow the exact working web callables
- client detail now exposes exact owner-only subscription status actions through `updateSubscription`
- the packages tab now mirrors the working web split between `Templates` and `Sold packages`
- package create/update/delete is now cleanly Samsung-verified
- owner-only subscription start-date and status actions are now cleanly Samsung-verified
- the Samsung blank-state edit bug was fixed by replacing the modal editor with a full-screen route

Additional Samsung verification for sold-packages parity:

- `Packages` now shows live split summary:
  - `9 templates`
  - `222 sold`
- tapping `Sold packages` opened the sold-subscriptions view with live summary chips:
  - `222 subscriptions`
  - `63 active`
  - `1 scheduled`
  - `157 expired`
  - `0 replaced`
- live sold row `ali vs` rendered with:
  - phone `668686868`
  - package `1 kunlik`
  - status `Expired`
  - visits `0 / 1`
  - dates `2026-04-07`
- sold-row `Edit` PASS for route entry:
  - route title `Edit start date`
  - client `ali vs`
  - date field rendered
  - `Save changes` action rendered
- sold-row `Replace` PASS for route entry:
  - route title `Replace package`
  - client `ali vs`
  - real package list rendered
  - replacement package choices visible
- sold-row `Replace` submit PASS end to end:
  - selected replacement package `L-VIP`
  - payment editor rendered with:
    - `Package total = 1400000 so'm`
    - `Paid = 1400000 so'm`
    - `Remaining = 0 so'm`
  - replacement comment entered: `codexreplaceqa`
  - after `Confirm package replacement`, Samsung returned to `Sold packages` with:
    - `223 subscriptions`
    - `64 active`
    - `156 expired`
    - `1 replaced`
  - current visible row for `ali vs` then showed:
    - package `L-VIP`
    - status `Active`
    - visits `0 / 180`
    - end date `2026-10-03`

Supporting evidence:

- `build/packages_templates_live.png`
- `build/packages_sold_live.png`
- `build/packages_sold_scrolled_live.png`
- `build/packages_sold_actions_probe.png`
- `build/packages_sold_edit_route_live.png`
- `build/packages_sold_replace_route_live.png`
- `build/replace_comment_entered.png`
- `build/replace_submit_result_wait4.png`

## 5. Safe Limits Kept

- No backend code changed
- No Firestore rules changed
- No indexes changed
- No schema changed
- No guessed callable names were used
- The mobile default-date fix aligned to the existing working web contract instead of inventing a new one

## 6. Exact Remaining Blockers

1. No package-contract blocker remains in this slice; only intentional disposable production test data may need later cleanup.

## 7. Safe Next Actions

1. Keep the UTC date-default behavior aligned with the working web activation drawer.
2. Reuse this audited template CRUD flow whenever owner-side package definitions need to change on mobile.
3. Reuse this audited sale flow whenever a client needs a new active package before session start.
4. Keep future replacement submits on disposable clients unless the business explicitly wants production replacements from mobile.
