# Mobile Contract Map

Status: Explicit web source-of-truth discovered and wired into mobile auth/onboarding
Audit date: 2026-04-07
Workspace: `D:\mobileallclubs`

Primary source repo:

- `D:\agentallclubs`

Canonical web files audited in this pass:

- `D:\agentallclubs — копия\src\pages\Login.jsx`
- `D:\agentallclubs — копия\src\context\AuthContext.jsx`
- `D:\agentallclubs — копия\src\services\onboardingService.js`
- `D:\agentallclubs — копия\src\pages\CreateClub.jsx`
- `D:\agentallclubs — копия\src\pages\VerifyEmail.jsx`
- `D:\agentallclubs — копия\src\App.jsx`
- `D:\agentallclubs — копия\src\components\RequireGym.jsx`
- `D:\agentallclubs — копия\src\pages\StaffList.jsx`
- `D:\agentallclubs — копия\src\pages\staff\domain\useStaffs.js`
- `D:\agentallclubs — копия\src\components\RequireRole.jsx`
- `D:\agentallclubs — копия\src\pages\staff\CreateStaffPage.jsx`
- `D:\agentallclubs — копия\src\firebase.js`
- `D:\agentallclubs — копия\functions\index.js`

## 1. Auth Method

Exact method(s) found:

- Login: Firebase email/password via `signInWithEmailAndPassword`
- Registration: Firebase email/password via `createUserWithEmailAndPassword`
- Password reset: `sendPasswordResetEmail`
- Email verification: `sendEmailVerification`

Exact source file(s):

- `D:\agentallclubs — копия\src\pages\Login.jsx`
- `D:\agentallclubs — копия\src\pages\VerifyEmail.jsx`

Confidence level:

- High

## 25. Super Admin Bootstrap Contract

Exact callable used by the working web auth bootstrap:

- `syncSuperAdminAccess`

Exact allowlist source:

- `D:\agentallclubs\shared\super-admin.json`
- current exact email list:
  - `jafaralituraev@gmail.com`

Exact bootstrap behavior used by the working web app:

1. if `users/{uid}` is missing or its `role` is not `super_admin`
2. and the authenticated email is in the super-admin allowlist
3. call `syncSuperAdminAccess()`
4. force-refresh the ID token
5. re-read `users/{uid}`
6. if the doc is still missing, fall back locally to:
  - `role: "super_admin"`
  - `isActive: true`
  - `localSuperAdminFallback: true`

Exact backend side-effects:

- writes/merges `users/{uid}` with:
  - `uid`
  - `email`
  - `role: "super_admin"`
  - `isActive: true`
  - `superAdminEnabledAt`
  - `updatedAt`
  - `createdAt`
- sets custom user claims from `getSuperAdminClaims()`

Exact source files:

- `D:\agentallclubs\src\config\superAdmin.js`
- `D:\agentallclubs\src\context\AuthContext.jsx`
- `D:\agentallclubs\functions\index.js`
- `D:\agentallclubs\functions\superAdminConfig.js`
- `D:\agentallclubs\shared\super-admin.json`

Confidence level:

- High

## 26. Onboarding Lock Recovery Contract

Exact callable exposed by the working web onboarding service:

- `clearOnboardingLock`

Exact request payload:

- `uid`

Exact backend behavior:

1. requires authenticated caller
2. resolves the actor gym from the caller
3. requires owner access for that gym
4. deletes `onboardingLocks/{uid}`
5. returns:
  - `success`
  - `uid`

Exact source files:

- `D:\agentallclubs\src\services\onboardingService.js`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 23. Owner Analytics Contract

Exact callable used by the working web dashboard:

- `getOwnerAnalytics`

Exact request payload:

- optional `date`
- working web default is `new Date().toISOString().slice(0, 10)`

Exact response shape discovered from backend/runtime:

- `date`
- `gyms[]`
- `summary`
  - `totalSessions`
  - `activeClients`
  - `revenue`
  - `newClients`

Exact gym row fields returned by the callable:

- `gymId`
- `gymName`
- `totalSessions`
- `activeClients`
- `newClients`
- `revenue`
- `peakHours[]`
  - `hour`
  - `sessionsCount`

Exact backend behavior:

- requires authenticated owner access
- resolves owned gyms from the caller
- reads gym-level `dailyStats/{dateKey}` documents written by the runtime stats pipeline

Exact source files:

- `D:\agentallclubs\src\modules\dashboard\domain\useGymAnalytics.js`
- `D:\agentallclubs\functions\index.js`
- `D:\agentallclubs\functions\runtime.js`

Confidence level:

- High

## 24. Client Insights Contract

Exact callable used by the working web client analytics flow:

- `getClientInsights`

Exact request payload:

- `clientId`

Exact backend behavior:

1. requires authenticated owner or staff access in the current gym
2. reads `gyms/{gymId}/clientInsights/{clientId}`
3. if the doc is missing, computes and writes it through `writeClientAnalytics(gymId, clientId)`

Exact response shape discovered from backend/runtime:

- `clientId`
- `attendanceTrend`
  - `direction`
  - `delta`
  - `last30`
  - `previous30`
- `visitFrequency`
  - `visitsPerWeek`
- `inactiveDays`
- `lastVisitAt`
- `churnRisk`
- `lifetimeValue`
- `alerts[]`
  - `type`
  - `title`
  - `description`
  - `severity`

Exact source files:

- `D:\agentallclubs\src\modules\clients\domain\useClientAnalytics.js`
- `D:\agentallclubs\functions\index.js`
- `D:\agentallclubs\functions\runtime.js`

Confidence level:

- High

## 10. Client Finance Contract

Exact runtime data sources used by the working web client profile:

1. `TransactionContext` listens to `gyms/{gymId}/transactions`
2. The transactions query is `orderBy("createdAt", "desc")`
3. `TransactionContext` also listens to `gyms/{gymId}/financeTransactions`
4. The finance-transactions query is `orderBy("createdAt", "desc")`
5. `TransactionContext` also listens to `gyms/{gymId}/subscriptions` to enrich missing `subscriptionStatus`
6. Both transaction collections are merged in memory and sorted by `createdAt desc`

Exact web source files:

- `D:\agentallclubs — копия\src\context\transaction\TransactionContext.jsx`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientFinance.js`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientProfileSummary.js`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientFinancePanel.jsx`

Exact client finance behavior used by the working web profile:

- client transactions are filtered in memory by `clientId`
- payment rows are `type == "payment"` or `type == "payment_reverse"`
- the selected subscription is the current profile-selected subscription
- payment rows are matched to the selected subscription by:
  - direct `subscriptionId` match
  - or, if the transaction has no `subscriptionId` and there is only one subscription, it is linked
  - or, if the transaction has no `subscriptionId`, the transaction date must fall between the subscription `startDate` and `endDate`

Exact visible finance summary fields:

- `packageSnapshot.price`
- payment totals from matched transactions
- debt
- overpayment
- remaining amount to collect
- payments list fields:
  - `paymentMethod || type`
  - `category`
  - `amount`
  - `createdAt`

Exact finance write actions used by the working web profile:

- collect payment:
  - callable `createTransaction`
  - transaction payload:
    - `type: "payment"`
    - `category: "package"`
    - `clientId`
    - `subscriptionId`
    - `subscriptionStatus`
    - `paymentMethod`
    - `amount`
    - `comment`
- delete payment:
  - callable `createTransaction`
  - transaction payload:
    - `type: "payment_reverse"`
    - `category`
    - `clientId`
    - `subscriptionId`
    - `subscriptionStatus`
    - `paymentMethod`
    - `amount: -abs(amount)`
    - `comment`
    - `meta.originalTxId`
- restore reversed payment:
  - callable `createTransaction`
  - transaction payload:
    - `type: "payment"`
    - `category`
    - `clientId`
    - `subscriptionId`
    - `subscriptionStatus`
    - `paymentMethod`
    - `amount: abs(amount)`
    - `comment`
    - `meta.restoredFromTxId`

Confidence level:

- High

## 11. Staff Contract

Exact working web route:

- `/app/staffs`

Exact access contract:

- route is wrapped in `RequireOwner`
- gym context is required
- effective mobile access is owner only

Exact runtime data source used by the working web route:

1. `useStaffs()` reads the current `gymId` from auth
2. it opens a realtime collection stream on `gyms/{gymId}/users`
3. it does not add Firestore `where` clauses
4. it filters the returned docs locally to `role == "staff"`

Exact source files:

- `D:\agentallclubs — копия\src\App.jsx`
- `D:\agentallclubs — копия\src\pages\StaffList.jsx`
- `D:\agentallclubs — копия\src\pages\staff\domain\useStaffs.js`
- `D:\agentallclubs — копия\src\components\RequireRole.jsx`
- `D:\agentallclubs — копия\src\services\staffService.js`

Exact fields visibly used by the working web route:

- `fullName`
- `phone`
- `image`
- `isActive`
- `role`

Important runtime note:

- `staffService.getStaffByGym()` exists and queries global `users`
- the actual route wired in `App.jsx` uses `StaffList` + `useStaffs`
- mobile follows the working route contract, not the alternate helper query

Confidence level:

- High

## 12. Staff Creation Contract

Exact callable:

- `createStaff`

Exact access contract:

- authenticated owner only
- resolved `gymId` required

Exact request payload discovered from web and backend source:

- `email`
- `password`
- `fullName`
- `phone`

Exact backend side-effects discovered from source:

1. creates a Firebase Auth user with `emailVerified: true`
2. writes `users/{uid}` with:
   - `email`
   - `fullName`
   - `phone`
   - `gymId`
   - `role`
   - `isActive`
3. writes `gyms/{gymId}/users/{uid}` with:
   - `email`
   - `fullName`
   - `phone`
   - `role`
4. sets custom claims with `gymId` and `role: "staff"`

Exact response fields:

- `success`
- `userId`
- `email`

Exact source files:

- `D:\agentallclubs — копия\src\pages\staff\CreateStaffPage.jsx`
- `D:\agentallclubs — копия\src\firebase.js`
- `D:\agentallclubs — копия\functions\index.js`

Confidence level:

- High

## 13. Client Creation Write Contract

Exact callable used by the working create-client page:

- `createClient`

Important runtime nuance discovered from the working web app:

- the shared helper `clientService.createClient(gymId, clientData)` wraps the callable as `{ clientData }`
- the actual routed page `src/pages/clients/CreateClient.jsx` calls `createClientFn(...)` directly with a flat payload
- mobile follows the working routed-page contract, not the unused helper wrapper

Exact request payload sent by the working web page:

- `firstName`
- `lastName`
- `phone`
- `gender`
- `birthDate`
- `note`
- `image`

Exact optional upload behavior used by the working web page before the callable:

- if a photo is selected, it is uploaded to:
  - `gyms/{gymId}/clients/{timestamp}-{uid}.{ext}`
- the resulting download URL is passed as `image`

Exact backend behavior discovered from the callable source:

1. requires authenticated user
2. resolves `gymId` from `users/{uid}`
3. checks for duplicates on `gyms/{gymId}/clients` where `phone == phone`
4. creates a new doc under `gyms/{gymId}/clients/{clientId}`
5. persists:
   - `gymId`
   - `firstName`
   - `lastName`
   - `phone`
   - `gender`
   - `note`
   - `image`
   - `isArchived: false`
   - timestamps
   - `createdBy`

Exact response fields:

- `success`
- `clientId`
- `id`

Exact source files:

- `D:\agentallclubs\src\pages\clients\CreateClient.jsx`
- `D:\agentallclubs\src\firebase.js`
- `D:\agentallclubs\src\services\clientService.js`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 14. Client Card Binding Contract

Exact runtime path:

- `gyms/{gymId}/cards/{cardId}`

Exact working web behavior:

- card bind/unbind is a Firestore transaction, not a callable

Exact bind flow:

1. read `gyms/{gymId}/clients/{clientId}`
2. read `gyms/{gymId}/cards/{cardId}`
3. fail if the client doc does not exist
4. fail if the card doc already exists
5. fail if the client already has a different `cardId`
6. create/update `gyms/{gymId}/cards/{cardId}` with:
   - `clientId`
   - `createdAt: serverTimestamp()`
7. update the client doc with:
   - `cardId`

Exact remove flow:

1. read `gyms/{gymId}/cards/{cardId}`
2. fail if the card is linked to another client
3. delete `gyms/{gymId}/cards/{cardId}`
4. update `gyms/{gymId}/clients/{clientId}` with:
   - `cardId: null`

Exact known error codes surfaced by the web service:

- `INVALID_CARD`
- `CLIENT_NOT_FOUND`
- `CARD_ALREADY_LINKED`
- `CLIENT_ALREADY_HAS_CARD`
- `CARD_LINKED_TO_ANOTHER_CLIENT`

Exact source files:

- `D:\agentallclubs\src\services\clientService.js`

Confidence level:

- High

## 27. Client/Profile Update Contract Status

Exact web references found:

- `D:\agentallclubs\src\firebase.js`
  - `updateClientFn = call("updateClient")`
  - `updateProfileFn = call("updateProfile")`
- `D:\agentallclubs\src\services\clientService.js`
  - helper `updateClient(gymId, clientId, updateData)` forwards:
    - `clientId`
    - `updateData`

Exact backend export reality found:

- the visible export list in `D:\agentallclubs\functions\index.js` contains no:
  - `exports.updateClient = onCall(...)`
  - `exports.updateProfile = onCall(...)`

Safe mobile conclusion:

- mobile must keep client-edit and profile-edit flows blocked
- the visible web source currently exposes stale callable wrappers without a matching backend export body to follow safely
- implementing these writes in mobile would require guessing a production contract, so they remain intentionally blocked

Exact source files:

- `D:\agentallclubs\src\firebase.js`
- `D:\agentallclubs\src\services\clientService.js`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 15. Session Write Contract

Exact session start callable:

- `startSession`

Exact request payload used by the working web app:

- required: `clientId`
- optional: `lockerNumber`
- note: some web code also passes `keyType`, but the backend callable currently destructures only `clientId` and `lockerNumber`

Exact backend side-effects for session start:

1. requires authenticated user
2. resolves `gymId` from `users/{uid}`
3. creates a new doc in `gyms/{gymId}/sessions/{sessionId}`
4. persists:
   - `clientId`
   - `gymId`
   - `status: "active"`
   - `locker`
   - `startedAt`
   - `createdAt`
   - `updatedAt`
   - `createdBy`

Exact session-start response fields:

- `success`
- `sessionId`

Exact session end callable:

- `endSession`

Exact session-end request payload:

- `sessionId`

Exact backend side-effects for session end:

1. requires authenticated user
2. validates the target session is active
3. computes `barDebt`
4. updates the session with:
   - `status: "completed"`
   - `endedAt`
   - `updatedAt`
   - `endedBy`
   - `barDebt`
5. if the client has an active subscription, decrements remaining visits and increments visit/session counters

Exact session-end response fields:

- `success`
- `sessionId`
- `barDebt`

Exact source files:

- `D:\agentallclubs\src\pages\clients\ClientProfilePage.jsx`
- `D:\agentallclubs\src\modules\clients\ui\ClientsTable.jsx`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 16. Package Sale Contract

Exact package read runtime path used by the working web app:

1. `PackagesContext` streams `gyms/{gymId}/packages`
2. the primary query is `where("isArchived", "==", false)` plus `orderBy("createdAt", "desc")`
3. if the composite index is unavailable, the web runtime falls back to `where("isArchived", "==", false)` and sorts locally

Exact package-sale callable:

- `createSubscription`

Exact request payload used by the working web activation flow:

- `clientId`
- `packageId`
- `startDate`
- `amounts`
- `comment`
- `replaceId`

Exact payment amount object shape discovered from the working web payment modal:

- `cash`
- `terminal`
- `click`
- `debt`

Exact web default-start-date nuance that mobile must mirror:

- the working web drawer initializes `todayISO` with `new Date().toISOString().split("T")[0]`
- this is UTC-based, not local-device-date-based
- mobile originally used local `DateTime.now()` and produced a `scheduled` subscription on Samsung at local midnight
- mobile was corrected to mirror the web UTC ISO default exactly

Exact package-sale source files:

- `D:\agentallclubs\src\modules\packages\domain\PackagesContext.jsx`
- `D:\agentallclubs\src\modules\subscriptions\ui\ActivatePackageDrawer.jsx`
- `D:\agentallclubs\src\components\modals\PaymentModal.jsx`
- `D:\agentallclubs\src\services\subscriptionService.js`
- `D:\agentallclubs\src\firebase.js`

Confidence level:

- High

## 19. Package Admin Contract

Exact package template runtime path used by the working web app:

- `gyms/{gymId}/packages`

Exact route behavior discovered from the working web app:

- `/app/packages` shows package templates for gym users
- `/app/packages/create` is owner only
- edit and delete actions are available from the templates page for owners

Exact create callable:

- `createPackage`

Exact create request payload:

- `packageData.name`
- `packageData.duration`
- `packageData.bonusDays`
- `packageData.price`
- `packageData.visitLimit`
- `packageData.type = "fixed"`
- `packageData.isUnlimited = false`
- `packageData.startTime`
- `packageData.endTime`
- `packageData.freezeEnabled`
- `packageData.maxFreezeDays`
- `packageData.gender`
- `packageData.gradient`
- `packageData.description`

Exact create backend side-effects:

- creates `gyms/{gymId}/packages/{packageId}`
- stores:
  - `gymId`
  - `name`
  - `duration`
  - `bonusDays`
  - `price`
  - `visitLimit`
  - `type`
  - `isUnlimited`
  - `startTime`
  - `endTime`
  - `freezeEnabled`
  - `maxFreezeDays`
  - `gender`
  - `gradient`
  - `description`
  - `isArchived: false`
  - `archived: false`
  - timestamps
  - `createdBy`

Exact update callable:

- `updatePackage`

Exact update request payload:

- `packageId`
- `packageData.name`
- `packageData.duration`
- `packageData.bonusDays`
- `packageData.price`
- `packageData.visitLimit`
- `packageData.isUnlimited`
- `packageData.startTime`
- `packageData.endTime`
- `packageData.freezeEnabled`
- `packageData.maxFreezeDays`
- `packageData.gender`
- `packageData.gradient`
- `packageData.description`

Exact delete callable:

- `deletePackage`

Exact delete request payload:

- `packageId`

Exact delete backend side-effects:

- soft-archives the package doc by setting:
  - `isArchived: true`
  - `archived: true`
  - `archivedAt`
  - `archivedBy`
  - `updatedAt`
  - `updatedBy`

Important runtime note:

- the working web create and edit flows lock `visitLimit = duration + bonusDays`
- mobile mirrors that exact anti-abuse model

Exact source files:

- `D:\agentallclubs\src\modules\packages\domain\PackagesContext.jsx`
- `D:\agentallclubs\src\pages\packages\CreatePackage.jsx`
- `D:\agentallclubs\src\modules\packages\ui\EditPackageDrawer.jsx`
- `D:\agentallclubs\src\modules\packages\ui\DeletePackageModal.jsx`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 17. Client Archive Contract

Exact callable:

- `archiveClient`

Exact request payload used by the web service helper:

- `clientId`

Exact backend behavior discovered from callable source:

1. requires authenticated user
2. resolves `gymId` from `users/{uid}`
3. requires owner access for the current gym
4. reads `gyms/{gymId}/clients/{clientId}`
5. updates the client doc with:
   - `isArchived: true`
   - `archivedAt`
   - `archivedBy`
   - `updatedAt`
   - `updatedBy`

Exact response fields:

- `success`
- `clientId`

Exact source files:

- `D:\agentallclubs\src\services\clientService.js`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 18. Client Update Contract

Exact evidence found:

- web service helper calls callable `updateClient`
- payload shape used by the helper is:
  - `clientId`
  - `updateData`
- backend runtime utilities expose `normalizeProfileFieldPatch(patch)`
- allowed normalized fields visible in runtime source are:
  - `fullName`
  - `firstName`
  - `lastName`
  - `phone`
  - `photo`
  - `displayName`

Important blocker:

- the actual `exports.updateClient = onCall(...)` implementation was not found in the visible backend source
- no routed working web page was found using `updateClient`
- mobile must not guess the final callable behavior or accepted patch semantics

Exact source files:

- `D:\agentallclubs\src\services\clientService.js`
- `D:\agentallclubs\functions\runtime.js`

Confidence level:

- Partial

## 9. Sessions Contract

Exact sessions runtime path used by the working web app:

1. `SessionsContext` streams `gyms/{gymId}/sessions`
2. The stream query is `orderBy("createdAt", "desc")`
3. The stream is capped with `limit(500)`
4. `SessionsPage` optionally filters the in-memory list by `clientId` query param

Exact route and access contract:

- web route: `/app/sessions`
- optional filter: `/app/sessions?clientId={clientId}`
- route sits under `RequireGym`
- with the known production roles, the effective mobile access is `owner` or `staff`

Exact source files:

- `D:\agentallclubs — копия\src\App.jsx`
- `D:\agentallclubs — копия\src\pages\sessions\SessionsPage.jsx`
- `D:\agentallclubs — копия\src\modules\sessions\SessionsPage.jsx`
- `D:\agentallclubs — копия\src\modules\sessions\domain\SessionsContext.jsx`
- `D:\agentallclubs — копия\src\modules\sessions\domain\useSessions.js`
- `D:\agentallclubs — копия\src\modules\sessions\domain\useSessionSelectors.js`
- `D:\agentallclubs — копия\src\modules\sessions\ui\SessionsTable.jsx`
- `D:\agentallclubs — копия\src\services\sessionService.js`

Exact fields visibly used by the web sessions page:

- `id`
- `clientId`
- `clientName`
- `packageSnapshot.name`
- `locker`
- `startedAt`
- `checkIn`
- `checkInAt`
- `endedAt`
- `checkOut`
- `checkOutAt`
- `status`
- `staffName`
- `staff.name`
- `createdBy`
- `createdAt`

Exact derived values used by the web runtime:

- active sessions: `status == "active"`
- closed sessions: `status == "closed" || status == "completed"`
- online/offline row state: `!checkOut`
- duration: `checkIn -> checkOut || now`

Confidence level:

- High

## 2. Current User Profile Contract

Exact document path:

- `users/{uid}`

Exact bootstrap behavior:

1. Read `users/{uid}`
2. If the document does not exist, treat the session as authenticated but not onboarded yet
3. If the document exists, resolve role and `gymId`

Exact fields read by mobile bootstrap:

- `email`
- `gymId`
- `role`
- `isActive`
- `fullName`
- `firstName`
- `lastName`
- `phone`
- `photo`
- `photoURL`
- `displayName`

Exact source file(s):

- `D:\agentallclubs — копия\src\context\AuthContext.jsx`

Confidence level:

- High

## 3. Gym Resolution Contract

Exact lookup path/logic:

1. Read `users/{uid}`
2. If `role == super_admin`, stop there
3. Otherwise read `users/{uid}.gymId`
4. If `gymId` is missing, route to onboarding
5. Read `gyms/{gymId}/users/{uid}`
6. Read `gyms/{gymId}`
7. Missing gym membership or gym docs are tolerated as incomplete tenant context, not guessed

Exact source file(s):

- `D:\agentallclubs — копия\src\context\AuthContext.jsx`
- `D:\agentallclubs — копия\src\components\RequireGym.jsx`

Confidence level:

- High

## 4. Role Resolution Contract

Exact role source:

- Primary role source: `users/{uid}.role`
- Tenant mirror: `gyms/{gymId}/users/{uid}.role`

Exact role values:

- `owner`
- `staff`
- `super_admin`

Exact source file(s):

- `D:\agentallclubs — копия\src\context\AuthContext.jsx`

Confidence level:

- High

## 5. Onboarding Contract

Exact callable:

- `createGymAndUser`

Exact call shape:

- `createGymAndUser(firebaseUser, { gymData })`

Exact `gymData` payload discovered from web source:

- `name`
- `city`
- `phone`
- `firstName`
- `lastName`

Exact required fields enforced by the web onboarding service:

- `name`
- `city`

Exact source file(s):

- `D:\agentallclubs — копия\src\services\onboardingService.js`
- `D:\agentallclubs — копия\src\pages\CreateClub.jsx`

Confidence level:

- High

## 6. Safe Mobile Implementation Status

Implementable now / blocked:

- Implementable now

What is now implemented in mobile:

- real login
- real register
- real password reset
- real verification-email resend
- auth state restore
- protected routing
- onboarding-aware bootstrap
- contract-safe `createGymAndUser` wrapper using the exact discovered payload

Primary mobile implementation files:

- `lib/core/services/auth_bootstrap_resolver.dart`
- `lib/core/services/onboarding_service.dart`
- `lib/core/routing/app_router.dart`
- `lib/features/bootstrap/application/bootstrap_controller.dart`
- `lib/features/bootstrap/application/bootstrap_state.dart`
- `lib/features/auth/presentation/login_screen.dart`
- `lib/features/auth/presentation/register_screen.dart`
- `lib/features/auth/presentation/create_gym_screen.dart`
- `lib/features/auth/presentation/forgot_password_screen.dart`
- `lib/features/auth/presentation/verify_email_screen.dart`
- `lib/features/auth/presentation/authenticated_shell_screen.dart`

Safe conclusion:

- The contract-definition gap is closed.
- Mobile auth/bootstrap and onboarding now match the real working web contract.
- Live `createGymAndUser` execution was later proven on Samsung and is tracked in `docs/mobile_firebase_backend_connection_audit.md`.

## 7. Clients Contract

Exact clients collection path:

- `gyms/{gymId}/clients`

Exact read query used by the working web app:

- `where("isArchived", "==", false)`
- `orderBy("createdAt", "desc")`

Exact read mode:

- realtime stream via `onSnapshot`

Exact source file(s):

- `D:\agentallclubs — копия\src\services\clientService.js`
- `D:\agentallclubs — копия\src\modules\clients\domain\ClientsContext.jsx`
- `D:\agentallclubs — копия\src\pages\clients\ClientsPage.jsx`
- `D:\agentallclubs — копия\src\components\RequireRole.jsx`

Exact fields visibly used by the web clients list:

- `firstName`
- `lastName`
- `phone`
- `email`
- `image`
- `cardId`
- `isArchived`
- document id as `id`

Access contract:

- route is guarded by `RequireStaff`
- effective role access is `owner` or `staff`
- gym context is required

Confidence level:

- High

## 8. Client Detail Contract

Exact client detail document path:

- `gyms/{gymId}/clients/{clientId}`

Exact subscription summary runtime contract used by the working web profile:

1. `SubscriptionsContext` streams `gyms/{gymId}/subscriptions`
2. The stream query is `orderBy("createdAt", "desc")`
3. `useClientProfileSummary` filters the in-memory list by `clientId`
4. The filtered subscriptions are sorted by status priority and `startDate desc`

Exact session summary runtime contract used by the working web profile:

1. `SessionsContext` streams `gyms/{gymId}/sessions`
2. The stream query is `orderBy("createdAt", "desc")`
3. The stream is capped with `limit(500)`
4. `useClientAttendance` filters the in-memory list by `clientId`
5. The filtered sessions are sorted by `startedAt || endedAt || createdAt`

Important note:

- helper service methods for direct `where("clientId", "==", clientId)` queries do exist in the web repo
- they are not the primary data source used by the working client profile page
- mobile now matches the actual working web runtime path, not just the helper functions

Exact web source files audited for the detail contract:

- `D:\agentallclubs — копия\src\pages\clients\ClientProfilePage.jsx`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientProfileSummary.js`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientAttendance.js`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientPersonalInfo.jsx`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientSubscriptionCard.jsx`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientLiveStatusCard.jsx`
- `D:\agentallclubs — копия\src\services\subscriptionService.js`
- `D:\agentallclubs — копия\src\services\sessionService.js`

Exact client detail fields visibly used by the web profile:

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

Exact subscription summary fields visibly used by the web profile:

- `status`
- `packageSnapshot.name`
- `packageSnapshot.duration`
- `packageSnapshot.price`
- `packageSnapshot.isUnlimited`
- `visitLimit`
- `remainingVisits`
- `startDate`
- `endDate`
- `createdAt`

Exact session summary fields visibly used by the web profile:

- `status`
- `locker`
- `startedAt`
- `endedAt`
- `createdAt`
- `clientId`
- `subscriptionId`

Access contract:

- route is guarded by staff access in web
- effective mobile access remains `owner` or `staff`
- gym context is required

Confidence level:

- High

## 20. Bar Admin Contract

Exact bar category runtime path used by the working web app:

- `gyms/{gymId}/barCategories`

Exact category read query:

- `where("isActive", "==", true)`
- `orderBy("name")`

Exact category callables:

- `createBarCategory`
- `updateBarCategory`
- `deleteBarCategory`

Exact category request payloads:

- create:
  - `name`
- update:
  - `categoryId`
  - `name`
- delete:
  - `categoryId`

Exact category backend side-effects:

- create writes:
  - `name`
  - `nameLower`
  - `gymId`
  - `isActive: true`
  - timestamps
  - `createdBy`
- update writes:
  - `name`
  - `updatedAt`
  - `updatedBy`
- delete soft-archives by writing:
  - `isActive: false`
  - `updatedAt`
  - `archivedAt`
  - `archivedBy`

Exact bar product runtime path used by the working web app:

- `gyms/{gymId}/barProducts`

Exact product read query:

- `where("isActive", "==", true)`
- `orderBy("name")`

Exact product image upload behavior used by the working web page:

- selected image uploads to Firebase Storage path:
  - `barProducts/{timestamp}-{fileName}`
- the returned download URL is then passed into the callable payload as `image`

Exact product callables:

- `createBarProduct`
- `updateBarProduct`
- `deleteBarProduct`

Exact product request payloads discovered from the working web UI:

- create:
  - `data.categoryId`
  - `data.name`
  - `data.price`
  - `data.image`
  - `data.isActive = true`
- update:
  - `productId`
  - `updates.name`
  - `updates.price`
  - `updates.image`
- delete:
  - `productId`

Exact product backend side-effects:

- create uses `normalizeProductName(name)` as the document id
- create writes:
  - `categoryId`
  - `name`
  - `normalizedName`
  - `price`
  - `image`
  - `stock`
  - `isActive`
  - `gymId`
  - timestamps
  - `createdBy`
- update writes only changed fields plus:
  - `updatedAt`
  - `updatedBy`
- delete soft-archives by writing:
  - `isActive: false`
  - `updatedAt`
  - `archivedAt`
  - `archivedBy`

Exact incoming runtime path used by the working web app:

- `gyms/{gymId}/barIncoming`

Exact incoming read query:

- `orderBy("createdAt", "desc")`

Exact incoming callables:

- `createBarIncoming`
- `deleteBarIncoming`

Exact incoming create request payload:

- `items[]`
  - `productId`
  - `quantity`
  - `purchasePrice`

Exact incoming create backend side-effects:

- validates every referenced product
- increments `gyms/{gymId}/barProducts/{productId}.stock`
- creates `gyms/{gymId}/barIncoming/{incomingId}` with:
  - `gymId`
  - `invoiceNumber`
  - normalized `items`
  - `total`
  - timestamps
  - `createdBy`

Exact incoming delete request payload:

- `incomingId`

Exact incoming delete backend side-effects:

- decrements product stock for every invoice item
- deletes `gyms/{gymId}/barIncoming/{incomingId}`

Exact hold-check callable:

- `holdCheck`

Exact hold-check request payload:

- `checkId`

Exact hold-check backend side-effects:

- updates `gyms/{gymId}/barChecks/{checkId}` with:
  - `status: "held"`
  - `updatedAt`
  - `updatedBy`

Exact source files:

- `D:\agentallclubs\src\context\ProductContext.jsx`
- `D:\agentallclubs\src\pages\bar\NewProductPage.jsx`
- `D:\agentallclubs\src\modules\bar\admin\AdminProducts.jsx`
- `D:\agentallclubs\src\context\bar\BarContext.jsx`
- `D:\agentallclubs\src\pages\bar\IncomingHistoryPage.jsx`
- `D:\agentallclubs\src\pages\bar\MenuPage.jsx`
- `D:\agentallclubs\src\modules\bar\domain\barChecks.js`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 21. Staff Management Actions Contract

Exact callable set used by the working web app:

- `deactivateStaff`
- `removeStaff`
- `getActiveStaff`

Exact deactivate/reactivate request payload:

- `userId`
- `isActive`

Exact deactivate/reactivate backend side-effects:

- requires authenticated owner in the same gym
- updates global `users/{userId}` with:
  - `isActive`
  - `updatedAt`
  - `deactivatedAt` or `reactivatedAt`

Exact remove request payload:

- `userId`

Exact remove backend side-effects:

- requires authenticated owner in the same gym
- rejects removing the owner
- updates global `users/{userId}` with:
  - `isActive: false`
  - `updatedAt`
  - `updatedBy`
  - `deactivatedAt`
  - `deactivatedBy`
- updates tenant mirror `gyms/{gymId}/users/{userId}` with the same fields

Exact get-active-staff behavior:

- no request payload is required by the working web helper
- backend resolves `gymId` from the caller
- backend returns global `users` where:
  - `gymId == current gym`
  - `isActive == true`
  - `role in ["staff", "manager"]`

Exact source files:

- `D:\agentallclubs\src\pages\StaffList.jsx`
- `D:\agentallclubs\src\pages\staff\StaffPage.jsx`
- `D:\agentallclubs\src\services\staffService.js`
- `D:\agentallclubs\src\services\inviteService.js`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 22. Invite Flow Contract

Exact callable set used by the working web app:

- `sendInvite`
- `cancelInvite`
- `resendInvite`
- `getGymInvites`
- `validateInviteToken`
- `acceptInvite`

Exact owner-side send-invite request payload:

- `email`
- `role`
- `staffData`
  - `fullName`
  - `phone`
  - `photo`

Exact send-invite backend behavior:

- requires authenticated owner in the same gym
- normalizes and validates email
- rejects users already linked to another gym
- if an existing user has no `gymId`, assigns them directly and returns:
  - `success`
  - `userId`
  - `assignedExistingUser: true`
- otherwise creates root `invites/{inviteId}` with:
  - `gymId`
  - `email`
  - `role`
  - `status: "pending"`
  - `invitedBy`
  - `token`
  - `attempts`
  - `expiresAt`
  - `staffData`
  - `createdAt`
  - `updatedAt`

Exact cancel-invite request payload:

- `inviteId`

Exact cancel-invite backend side-effects:

- requires authenticated owner in the same gym
- updates root `invites/{inviteId}` with:
  - `status: "cancelled"`
  - `updatedAt`
  - `cancelledAt`
  - `cancelledBy`

Exact resend-invite request payload:

- `inviteId`

Exact resend-invite backend side-effects:

- requires authenticated owner in the same gym
- only allows `status == "pending"`
- updates root `invites/{inviteId}` with:
  - new `token`
  - `attempts: 0`
  - new `expiresAt`
  - `updatedAt`
  - `resentAt`
  - `resentBy`

Exact get-gym-invites behavior:

- requires authenticated owner
- backend resolves `gymId` from the caller
- returns root `invites` where:
  - `gymId == current gym`
  - ordered by `createdAt desc`

Exact validate-token request payload:

- `token`

Exact validate-token response:

- invalid cases:
  - `valid: false`
  - `error`
- valid case:
  - `valid: true`
  - `invite`
    - `id`
    - `email`
    - `role`
    - `gymId`
    - `status`
    - `staffData`
    - `expiresAt`

Exact accept-invite flow used by the web app:

1. `validateInviteToken({ token })`
2. `createUserWithEmailAndPassword(auth, invite.email, password)`
3. callable `acceptInvite({ token, fullName })`

Exact accept-invite backend side-effects:

- writes/merges global `users/{uid}` with:
  - `email`
  - `gymId`
  - `role`
  - `fullName`
  - `phone`
  - `photo`
  - `isActive`
  - `updatedAt`
  - `lastLoginAt`
  - `acceptedInviteId`
- writes/merges tenant `gyms/{gymId}/users/{uid}` with:
  - `uid`
  - `email`
  - `fullName`
  - `phone`
  - `role`
  - `updatedAt`
- updates root `invites/{inviteId}` with:
  - `status: "accepted"`
  - `acceptedBy`
  - `acceptedAt`
  - `updatedAt`
  - incremented `attempts`

Exact source files:

- `D:\agentallclubs\src\services\inviteService.js`
- `D:\agentallclubs\src\pages\AcceptInvitePage.jsx`
- `D:\agentallclubs\src\App.jsx`
- `D:\agentallclubs\src\context\AuthContext.jsx`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 27. Subscription Status Update Contract

Exact callable used by the working web subscription service:

- `updateSubscription`

Exact request payload:

- `subscriptionId`
- `updateData`

Exact working web helper variants:

- activate:
  - `status: "active"`
  - `activatedAt: new Date().toISOString()`
- deactivate:
  - `status: "inactive"`
  - `deactivatedAt: new Date().toISOString()`
- cancel/delete:
  - `status: "cancelled"`
  - `deletedAt: new Date().toISOString()`

Exact backend behavior:

1. requires authenticated owner access in the current gym
2. reads `gyms/{gymId}/subscriptions/{subscriptionId}`
3. merges `updateData`
4. always writes:
  - `gymId`
  - `updatedAt`
  - `updatedBy`

Exact source files:

- `D:\agentallclubs\src\services\subscriptionService.js`
- `D:\agentallclubs\functions\index.js`

Confidence level:

- High

## 28. Bar Settlement Contract

Exact additional bar callable set exposed by the backend:

- `refundCheck`
- `checkClientDebt`

Exact `refundCheck` request payload:

- `checkId`

Exact `refundCheck` backend behavior:

1. requires authenticated owner access in the current gym
2. reads `gyms/{gymId}/barChecks/{checkId}`
3. updates the check with:
  - `status: "refunded"`
  - `refundedAt`
  - `refundedBy`
  - `updatedAt`

Exact `checkClientDebt` request payload:

- `clientId`

Exact `checkClientDebt` response shape discovered from runtime:

- `totalDebt`
- `unpaidChecks[]`
  - `id`
  - `status`
  - `debtAmount`
  - `totalAmount`

Exact `checkClientDebt` backend behavior:

1. requires authenticated owner or staff access in the current gym
2. queries `gyms/{gymId}/barChecks`
3. filters to:
  - `clientId == target client`
  - `status in ["draft", "held"]`
4. returns normalized debt aggregation from runtime helpers

Exact source files:

- `D:\agentallclubs\functions\index.js`
- `D:\agentallclubs\functions\runtime.js`

Confidence level:

- High

## 29. Staff Update Contract

Exact callable exposed by the backend:

- `updateStaff`

Exact request payload:

- `userId`
- `updates`
  - `fullName`
  - `phone`
  - optionally `role`
  - optionally `isActive`

Exact backend behavior:

1. requires authenticated owner access in the current gym
2. reads the global user doc `users/{userId}`
3. verifies that `users/{userId}.gymId` matches the current gym
4. updates only the global user doc
5. always writes `updatedAt`

Important product note:

- the currently visible working web staff page does not call `updateStaff`
- mobile uses this exact callable only for safe `fullName` and `phone` edits
- mobile does not guess role-management UI beyond the explicit backend contract

Exact source files:

- `D:\agentallclubs\functions\index.js`
- `D:\agentallclubs\src\pages\staff\StaffPage.jsx`

Confidence level:

- High

## 30. Gym Daily Stats Contract

Exact callable exposed by the backend:

- `getGymDailyStats`

Exact request payload:

- `date`

Exact backend behavior:

1. requires authenticated gym-user access
2. resolves the caller gym through auth-linked membership
3. reads `gyms/{gymId}/dailyStats/{date}`
4. if the row is missing, computes and writes it through runtime helpers
5. returns:
  - `id`
  - `date`
  - `totalSessions`
  - `activeClients`
  - `newClients`
  - `revenue`

Exact source files:

- `D:\agentallclubs\functions\index.js`
- `D:\agentallclubs\functions\runtime.js`

Confidence level:

- High

## 31. Delete Transaction Contract

Exact callable exposed by the backend:

- `deleteTransaction`

Exact request payload:

- `transactionId`

Exact backend behavior:

1. requires authenticated owner access in the current gym
2. reads `gyms/{gymId}/transactions/{transactionId}`
3. throws `not-found` if the transaction doc is missing
4. deletes only the `gyms/{gymId}/transactions` doc

Important product note:

- this callable does not target `gyms/{gymId}/financeTransactions`
- mobile therefore exposes delete only for entries sourced from `transactions`

Exact source files:

- `D:\agentallclubs\functions\index.js`
- `D:\agentallclubs\src\firebase.js`

Confidence level:

- High
