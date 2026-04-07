# Mobile Dashboard Module Audit

Status: Owner analytics and gym daily stats are wired and Samsung-verified
Audit date: 2026-04-07
Workspace: `D:\mobileallclubs`

## 1. Exact Source Of Truth

Working web repo:

- `D:\agentallclubs`

Audited files:

- `D:\agentallclubs\src\modules\dashboard\domain\useGymAnalytics.js`
- `D:\agentallclubs\functions\index.js`
- `D:\agentallclubs\functions\runtime.js`

## 2. Real Dashboard Contract

Callables:

- `getOwnerAnalytics`
- `getGymDailyStats`

Exact request payloads:

- optional `date`
- mobile mirrors the working web day-key format `YYYY-MM-DD`

Exact `getOwnerAnalytics` response shape:

- `date`
- `summary`
  - `totalSessions`
  - `activeClients`
  - `revenue`
  - `newClients`
- `gyms[]`
  - `gymId`
  - `gymName`
  - `totalSessions`
  - `activeClients`
  - `newClients`
  - `revenue`
- `peakHours[]`

Exact `getGymDailyStats` response shape:

- `id`
- `date`
- `totalSessions`
- `activeClients`
- `newClients`
- `revenue`

Exact access rules:

- `getOwnerAnalytics`: owner only
- `getGymDailyStats`: authenticated owner or staff with resolved gym membership

## 3. What Was Implemented In Mobile

- real `Stats` route for resolved owner/staff gym users
- exact `getGymDailyStats` callable wrapper
- exact `getOwnerAnalytics` callable wrapper
- current-gym daily stats card
- last-30-days owner loader mirroring the working web runtime pattern
- latest summary chips
- owned-gym breakdown card
- recent-days history section
- clean loading / error / empty states

Implementation files:

- `lib/features/dashboard/domain/owner_analytics_models.dart`
- `lib/features/dashboard/application/dashboard_providers.dart`
- `lib/features/dashboard/presentation/dashboard_screen.dart`
- `lib/core/widgets/app_shell_scaffold.dart`
- `lib/core/routing/app_router.dart`

## 4. What Was Verified On Samsung

- owner session restored successfully
- tapping the header `Stats` action opened the new dashboard route
- route first showed the live daily-stats loading state:
  - `Loading today through getGymDailyStats...`
- after waiting on Samsung, the route showed the exact `getGymDailyStats` card for `Rezone`:
  - date `2026-04-07`
  - revenue `0`
  - sessions `0`
  - active clients `1`
  - new clients `0`
- the same route then showed owner analytics through `getOwnerAnalytics` for the same date:
  - date `2026-04-07`
  - revenue `0`
  - sessions `0`
  - active clients `1`
  - new clients `0`

Evidence:

- `build/mobile_stats_open.png`
- `build/mobile_stats_after_wait.png`
- `build/mobile_daily_stats_live.png`
- `build/mobile_daily_stats_wait_20s.png`
- `build/window_dump_stats_20s.xml`

## 5. Local Verification

- `flutter analyze`: PASS
- `flutter test`: PASS
- `flutter build apk --debug`: PASS
- `adb install -r build/app/outputs/flutter-apk/app-debug.apk`: PASS

## 6. Safe Limits Kept

- No backend code changed
- No Firestore rules changed
- No indexes changed
- No schema changed
- No guessed callable names or payloads were introduced

## 7. Safe Next Actions

1. Re-run the same `Stats` route with a real staff account and capture the `getGymDailyStats` card on Samsung.
2. Keep owner analytics blocked for staff until the web contract explicitly changes.
3. Continue with the remaining callable-backed write categories while preserving the same owner/staff access rules.
