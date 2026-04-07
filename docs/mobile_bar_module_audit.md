# Mobile Bar Module Audit

Audit date: 2026-04-07
Workspace: `D:\mobileallclubs`

## 1. Scope

This pass implemented the remaining explicit bar admin contracts discovered from the working web source-of-truth without changing backend code, Firestore rules, indexes, DB paths, or schema.

Implemented in mobile:

- exact `holdCheck` callable wrapper
- exact `refundCheck` callable wrapper
- exact `checkClientDebt` callable wrapper
- owner-only bar admin route
- exact bar category CRUD wrappers:
  - `createBarCategory`
  - `updateBarCategory`
  - `deleteBarCategory`
- exact bar product CRUD wrappers:
  - `createBarProduct`
  - `updateBarProduct`
  - `deleteBarProduct`
- exact bar incoming wrappers:
  - `createBarIncoming`
  - `deleteBarIncoming`
- exact active-category/product streams
- exact incoming-history stream
- exact Firebase Storage image upload path for bar products:
  - `barProducts/{timestamp}-{fileName}`

Primary implementation files:

- `lib/features/bar/application/bar_actions_service.dart`
- `lib/features/bar/application/bar_providers.dart`
- `lib/features/bar/domain/bar_incoming_invoice_summary.dart`
- `lib/features/bar/domain/bar_session_check_summary.dart`
- `lib/features/bar/presentation/bar_admin_screen.dart`
- `lib/features/bar/presentation/bar_menu_screen.dart`
- `lib/features/bar/presentation/bar_pos_screen.dart`
- `lib/core/routing/app_router.dart`

## 2. Source-Of-Truth Contracts Used

Category contracts:

- collection: `gyms/{gymId}/barCategories`
- read query: `where("isActive", "==", true) + orderBy("name")`
- create payload: `{ name }`
- update payload: `{ categoryId, name }`
- delete payload: `{ categoryId }`

Product contracts:

- collection: `gyms/{gymId}/barProducts`
- read query: `where("isActive", "==", true) + orderBy("name")`
- create payload:
  - `{ data: { categoryId, name, price, image, isActive: true } }`
- update payload:
  - `{ productId, updates: { name, price, image } }`
- delete payload:
  - `{ productId }`
- image upload path:
  - `barProducts/{timestamp}-{fileName}`

Incoming contracts:

- collection: `gyms/{gymId}/barIncoming`
- read query: `orderBy("createdAt", "desc")`
- create payload:
  - `{ items: [{ productId, quantity, purchasePrice }] }`
- delete payload:
  - `{ incomingId }`

POS hold contract:

- callable: `holdCheck`
- payload:
  - `{ checkId }`

POS settlement contracts:

- `refundCheck`
  - payload `{ checkId }`
- `checkClientDebt`
  - payload `{ clientId }`
  - response `{ totalDebt, unpaidChecks }`

## 3. Verification

Local verification:

- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build apk --debug`: PASS
- keyboard-aware shell regression test: PASS
  - `hides the shared bottom dock while the keyboard is visible`

Android device visibility:

- `adb devices -l`: PASS
- `flutter devices`: PASS
- Samsung device id: `RFCY706YLXD`

Android install:

- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS

Important truth:

- `POS Menu` is cleanly Samsung-verified
- `Bar admin` route is now cleanly Samsung-verified:
  - title `Bar admin`
  - section chips `Categories / Products / Incoming`
  - category create form
  - existing category cards with `Edit` and `Delete`
- `Bar POS` inner route is now cleanly Samsung-verified after the latest render hardening:
  - route title `Bar POS` renders on Samsung
  - current session card renders on Samsung
  - category chips render on Samsung
  - product card renders on Samsung
  - current-check card renders on Samsung
  - debt card renders on Samsung
  - check-history card renders on Samsung
- `Bar admin` blank-state root cause was identified locally:
  - the categories tab had real Flutter layout failures caused by narrow mobile constraints
  - first failure path: unconstrained `FilledButton` inside the create-category row
  - second failure path: `ListTile.trailing` action buttons consuming the entire tile width
  - the screen was simplified in `lib/features/bar/presentation/bar_admin_screen.dart`:
    - manual section chips replaced the fragile `TabBarView` path
    - tab bodies now use explicit width-constrained scroll layouts
    - category, product, and incoming cards use custom stacked actions instead of risky trailing button wraps
- widget tests now prove the owner bar-admin render paths locally:
  - `test/widget_test.dart`
  - `renders the owner-only bar admin categories content`
  - `renders the owner-only bar admin products content`
  - `renders the owner-only bar admin incoming content`
- the shell and bar-admin scroll containers are now hardened for keyboard-open states:
  - bottom dock hides while the keyboard is visible
  - bar-admin category/product/incoming tabs add keyboard-aware bottom padding
  - this specifically targets the Samsung `BOTTOM OVERFLOWED BY 40 PIXELS` category-input bug
  - fresh Samsung evidence:
    - `build/bar_admin_category_focus_after_fix.png`
    - `build/window_dump_bar_admin_category_focus_after_fix.xml`
- widget tests now prove the `Bar POS` route render path locally:
  - `test/widget_test.dart`
  - `renders the bar POS client, products, cart, and history`
- the latest debug APK is built locally with these fixes
- live Samsung proof now exists for these exact POS actions:
  - `Open POS` render PASS
  - `Open guest POS` render PASS
  - guest route opened from the global POS menu
  - guest header rendered `Guest POS`
  - guest info card rendered the web contract explanation
  - guest draft creation PASS through exact `createCheck(null, null)`
  - guest `addItem` PASS with disposable draft check `c2BqSRtngcjsLW8MpNKQ`
  - visible success state: `ide cofee added to the active check.`
  - visible guest stock change: `12 -> 11`
  - guest `holdCheck` PASS
  - after hold, guest `Current check` returned to the empty draft state
  - guest `voidCheck` PASS
  - disposable guest draft cleared and stock rolled back `9 -> 10`
  - guest `payCheck` PASS
  - disposable guest draft cleared after payment while stock remained `9`
  - `addItem` PASS
  - `holdCheck` PASS
  - `checkClientDebt` PASS
  - `voidCheck` PASS
  - `payCheck` PASS
  - `refundCheck` PASS
- live Samsung proof now exists for this exact bar-admin write action:
  - `createBarCategory` PASS
  - disposable category created: `CodexCat410`
  - visible success state: `Category created.`
- additional live Samsung proof now exists for these exact bar-admin write actions:
  - `deleteBarCategory` PASS
  - disposable category archived: `CodexCat410`
  - visible success state: `Category archived.`
  - `updateBarCategory` PASS
  - disposable category renamed: `CodexCat411 -> CodexCat411B`
  - visible success state: `Category updated.`
  - cleanup archive PASS
  - disposable category archived after rename: `CodexCat411B`
  - visible success state: `Category archived.`
  - `createBarProduct` PASS
  - disposable product created under `CodexCat410`: `CodexDrink410`
  - visible success state: `Product created.`
  - `createBarIncoming` PASS
  - disposable invoice created: `INC-KPMNME`
  - visible success state: `Incoming invoice saved.`
  - `deleteBarIncoming` PASS
  - disposable invoice deleted: `INC-KPMNME`
  - visible success state: `Incoming invoice deleted.`
  - `updateBarProduct` PASS
  - disposable product renamed: `CodexSweet413 -> CodexSweet413B`
  - visible success state: `Product updated.`
  - `deleteBarProduct` PASS
  - disposable product archived: `CodexSweet413B`
  - visible success state: `Product archived.`
- refund was executed only against a disposable paid check created during this pass, not against an older non-disposable production check

## 4. Exact Remaining Runtime Gaps

1. Keyboard/back behavior on Samsung can still make adb-driven form interaction flaky, especially on text-entry dialogs.
2. The exact category-input keyboard overflow is now Samsung-verified as fixed:
   - category field focused with the keyboard open
   - no visible overflow banner
   - no `BOTTOM OVERFLOWED` / `RenderFlex overflowed` lines in filtered logcat
3. Guest route open/create-check/add-item/hold/pay/void is now Samsung-verified.

## 5. Safe Next Actions

1. Keep `Check debt` coverage on clients with held checks to confirm totals stay truthful.
2. Keep refunds limited to disposable paid checks created during testing.
3. Move to the next still-open mobile-write slice outside bar, such as invite acceptance, onboarding recovery, or any remaining Samsung proof gaps.
