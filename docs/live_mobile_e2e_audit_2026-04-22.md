# Live Mobile E2E Audit

Date: 2026-04-22
Tester: Codex live Android audit
Device: Samsung `SM A576B`
Build under test: debug/dev build on physical Android device
Workspace: `D:\mobileallclubs`
Artifacts: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22`

## Scope

Real-device navigation and interaction audit for the staff flow:

- Login, forgot password, register
- Clients list, search, filters, client detail
- Sessions list, date filters, session expansion
- Finance overview and transactions
- Packages templates and subscriptions
- Global header shortcuts: POS, Stats, Profile
- Profile -> Settings -> Language
- Create client route

The following actions were intentionally not completed because they can mutate live backend data:

- Creating a client
- Starting or ending sessions
- Binding cards / giving keys
- Opening guest/client POS flows past the menu
- Completing payments or package activation

## Areas That Worked

- Login screen, forgot password route, register route all opened correctly.
- Staff login succeeded with the documented test account.
- Clients list loaded real data.
- Clients `Online` and `Active` filters switched correctly.
- Client search by phone digits worked and narrowed results correctly.
- Client detail opened from the clients list.
- Replace package screen opened from client detail.
- Sessions screen loaded real live sessions.
- Sessions date-range bottom sheet opened with all expected options.
- Finance `Overview` and `Transactions` tabs switched correctly.
- Packages `Templates` and `Subscriptions` tabs switched correctly.
- Packages `Active`, `Replaced`, and `Expired` subscription filters switched correctly.
- Header shortcuts `Stats`, `POS`, and `Profile` all opened dedicated screens.
- Profile `Settings` and language selector opened.

## Findings

### 1. `Add client` screen traps the user because both back paths failed in live testing

Severity: High

Live behavior:

- The in-app `Back` button on the `Add client` screen did not navigate away.
- Android system back also did not navigate away.
- Normal field taps still worked, so this was not a fully frozen screen.

Evidence:

- Screenshot: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_add_client_01.png`
- Screenshot after in-app back attempt: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_after_add_client_back.png`
- Screenshot after system back attempt: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_after_add_client_system_back.png`
- XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_add_client_01.xml`
- XML after in-app back: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_after_add_client_back.xml`
- XML after system back: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_after_add_client_system_back.xml`

Relevant code:

- `lib/features/clients/presentation/create_client_screen.dart:237`
- `lib/core/routing/app_router.dart:224`
- `lib/core/widgets/app_route_back_scope.dart:15`

### 2. `Client profile` in-app back button failed on device

Severity: High

Live behavior:

- Tapping the top-left back button on `Client profile` did not return to clients.
- Android system back did return to the clients list.

Evidence:

- Screenshot: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_client_detail_ali_01.png`
- Screenshot after in-app back attempt: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_client_detail_back_01.png`
- Screenshot after system back: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_client_detail_system_back_01.png`
- XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_client_detail_ali_01.xml`

Relevant code:

- `lib/features/clients/presentation/client_detail_screen.dart:719`
- `lib/core/routing/app_router.dart:281`

### 3. Debug-only Firebase diagnostics controls are visible across staff-facing screens in the demo build

Severity: High for demos, Medium for release quality

Live behavior:

- `Open Developer Firebase Diagnostics` was visible on login, clients, sessions, finance, packages, and client detail.
- On login, opening diagnostics and pressing Android back returned out of the app flow instead of back to login.

Why this matters:

- A client-facing demo should not expose developer diagnostics.
- The login screen uses `context.go('/dev/firebase-diagnostics')`, so back-stack behavior is poor for a debug-only route.

Evidence:

- Login diagnostics screenshot: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_diagnostics_01.png`
- Sessions empty-state XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_sessions_completed.xml`
- Finance XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_finance_01.xml`
- Packages replaced XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_packages_replaced.xml`

Relevant code:

- `lib/features/auth/presentation/login_screen.dart:200`
- `lib/features/clients/presentation/clients_screen.dart:464`
- `lib/features/clients/presentation/client_detail_screen.dart:886`
- `lib/features/sessions/presentation/sessions_screen.dart:361`
- `lib/features/finance/presentation/finance_screen.dart:328`
- `lib/features/finance/presentation/finance_screen.dart:498`
- `lib/features/packages/presentation/packages_screen.dart:443`

### 4. Stats screen data is inconsistent with live sessions data

Severity: High

Live behavior:

- `Stats` showed `Revenue 0` and `Sessions 0` for `2026-04-22`.
- At the same time, `Sessions` showed 3 live sessions with amounts, and `Clients` showed 3 online clients.

Why this matters:

- This looks like a source-of-truth mismatch between dashboard callable stats and live session/module data.
- A client demo will read this as incorrect analytics.

Evidence:

- Stats screenshot: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_stat_01.png`
- Sessions screenshot: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_sessions_01.png`
- Sessions XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_sessions_01.xml`

Relevant code:

- `lib/features/dashboard/presentation/dashboard_screen.dart:27`
- `lib/features/dashboard/presentation/dashboard_screen.dart:376`
- `lib/features/dashboard/application/dashboard_providers.dart:73`

### 5. `Birth date` picker on `Add client` did not open from the field or the calendar icon

Severity: Medium

Live behavior:

- Tapping the `Birth date` row did not open the picker.
- Tapping the calendar icon also did not open the picker.
- In the UI dump, the `Birth date` view exposed `clickable=false` even though the Flutter widget is wired with `onTap`.

Evidence:

- Screenshot: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_add_client_submit_empty.png`
- XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_add_client_first_name_focus.xml`
- XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_add_client_birthdate_icon.xml`

Relevant code:

- `lib/features/clients/presentation/create_client_screen.dart:71`
- `lib/features/clients/presentation/create_client_screen.dart:366`

### 6. `History` in Sessions behaves like “all sessions”, not historical sessions

Severity: Medium

Live behavior:

- On `Today`, `History` showed the same three online sessions already visible in `Online`.
- This is confusing for users because the label implies past or archived history.

Code confirmation:

- The current implementation returns `true` for every session under `_SessionViewFilter.history`.

Evidence:

- Online XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_sessions_today_again.xml`
- History XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_sessions_history.xml`

Relevant code:

- `lib/features/sessions/presentation/sessions_screen.dart:439`
- `lib/features/sessions/presentation/sessions_screen.dart:1886`

### 7. Clients filter pills become visually clipped when search is active

Severity: Medium

Live behavior:

- After searching by phone, the `Passive Clients` pill was pushed off-screen and only partially visible.
- The row is horizontally scrollable in code, but the on-device result still looks broken and easy to miss.

Evidence:

- Screenshot: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_clients_search_01.png`
- XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_clients_search_01.xml`

Relevant code:

- `lib/features/clients/presentation/clients_screen.dart:22`
- `lib/features/clients/presentation/clients_screen.dart:530`

### 8. Session expansion/back behavior is confusing on device

Severity: Medium

Live behavior:

- Expanding a session exposed details inside the sessions screen.
- Android system back did not collapse that expanded state.
- Because the expanded state looks route-like but behaves in-place, the interaction is confusing during real use.

Evidence:

- Session detail screenshot: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\live_session_detail_01.png`
- XML: `D:\mobileallclubs\docs\live_mobile_e2e_artifacts_2026-04-22\allclubs_session_detail_01.xml`

Relevant code:

- `lib/features/sessions/presentation/sessions_screen.dart:300`
- `lib/features/sessions/presentation/sessions_screen.dart:333`

### 9. Local automated regression check still has two failing session goldens

Severity: Medium

Automated behavior:

- `flutter analyze` passed.
- `flutter test` failed on two goldens:
  - `goldens/sessions_shared_avatar.png`
  - `goldens/sessions_calendar_shared_controls.png`

Why this matters:

- These regressions line up with the parts of the UI where the live sessions surface already feels unstable.

## Coverage Notes

Verified live on device:

- Login, forgot password, register, diagnostics
- Clients search and filters
- Client detail and replace package route
- Sessions filters and range sheet
- Finance tabs
- Packages tabs and sold-subscription status filters
- Stats, POS menu, profile, settings, language selector
- Add client route and form focus behavior

Not fully executed because of live-data mutation risk:

- Create client final submit
- POS order creation
- Payment collection / transaction deletion
- Session end / session start
- Card binding / key issuance

## Suggested Next Fix Order

1. Fix back navigation on `Add client` and `Client profile`.
2. Remove or hard-hide diagnostics controls from any client/demo build.
3. Reconcile `Stats` numbers with live session data.
4. Fix `Birth date` interactivity on `Add client`.
5. Rename or rework `History` in Sessions so it matches user expectation.
6. Clean up clipped pills and expanded-session back behavior.
