# Mobile Client Finance Audit

Status: Client finance summary and payment collect/reverse/restore actions are Samsung-verified
Audit date: 2026-04-07
Workspace: `D:\mobileallclubs`

## 1. Exact Source Of Truth

Working web repo:

- `D:\agentallclubs — копия`

Audited files:

- `D:\agentallclubs — копия\src\context\transaction\TransactionContext.jsx`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientFinance.js`
- `D:\agentallclubs — копия\src\modules\clients\domain\useClientProfileSummary.js`
- `D:\agentallclubs — копия\src\modules\clients\ui\profile\ClientFinancePanel.jsx`

## 2. Real Client Finance Contract

Exact runtime collections:

- `gyms/{gymId}/transactions`
- `gyms/{gymId}/financeTransactions`
- `gyms/{gymId}/subscriptions`

Exact runtime queries:

- `transactions`: `orderBy("createdAt", "desc")`
- `financeTransactions`: `orderBy("createdAt", "desc")`
- `subscriptions`: full collection listener without extra query clauses

Exact runtime behavior:

- transactions from both collections are merged in memory
- merged transactions are sorted by `createdAt desc`
- missing `subscriptionStatus` values are enriched from the subscriptions map
- client detail filters the merged transactions by `clientId`
- selected payments are linked to the currently selected subscription by:
  - direct `subscriptionId`
  - or single-subscription fallback
  - or transaction date inside the subscription date range

Exact visible read-only summary fields implemented in mobile:

- package price
- paid amount
- debt
- overpayment
- remaining amount
- payments list:
  - payment method or type
  - category
  - amount
  - created date

## 3. What Was Implemented In Mobile

- real merged read-only transaction stream from:
  - `gyms/{gymId}/transactions`
  - `gyms/{gymId}/financeTransactions`
- real subscription listener for transaction enrichment
- client-filtered transactions provider
- read-only finance summary card inside client detail
- linked payments list for the currently selected subscription
- real collect-payment flow via `createTransaction`
- real reverse-payment flow via `createTransaction(type=payment_reverse)`
- real restore-payment flow via `createTransaction(type=payment)`

Implementation files:

- `lib/features/finance/domain/gym_transaction_summary.dart`
- `lib/features/finance/application/payment_actions_service.dart`
- `lib/features/finance/application/transaction_providers.dart`
- `lib/features/clients/presentation/client_detail_screen.dart`

## 4. Verification

Local verification:

- `flutter analyze`: PASS
- `flutter test`: PASS

Widget test coverage:

- client detail now renders the finance summary card
- payment totals are rendered
- linked payment rows are rendered for the selected subscription

Samsung verification:

- PASS
- verified live on Samsung with production owner account in `Rezone`
- path exercised:
  - authenticated shell
  - `Clients`
  - `SHOXRUX KOMILOV`
  - `Client profile`
  - `Finance summary`
- visible live values on Samsung:
  - package price: `40000`
  - paid amount: `0`
  - debt: `40000`
  - overpayment: `0`
  - remaining: `40000`
  - linked payments: `0`
- disposable finance-write proof then closed on Samsung with client `ali vs`
- exact safe live path:
  - `Clients`
  - `ali vs`
  - `Activate package`
  - select `1 kunlik`
  - choose `Cash`
  - `Confirm package sale`
  - return to `Client profile -> Finance summary`
- live package sale created a linked payment row with:
  - `Linked payments = 1`
  - `cash`
  - `40000`
  - `2026-04-07 17:03`
- `Delete` on that payment PASS:
  - exact confirm dialog title `Delete payment`
  - dialog text confirmed a reversing transaction would be created
  - after submit Samsung showed:
    - `Payment reversed.`
    - `Paid amount = 0`
    - `Debt = 40000`
    - `Linked payments = 2`
    - new reversing row `cash -40000`
- `Restore` on that reversing row PASS:
  - exact confirm dialog title `Restore payment`
  - dialog text confirmed a compensating payment transaction would be created
  - after submit Samsung showed:
    - `Payment restored.`
    - `Paid amount = 40000`
    - `Debt = 0`
    - `Linked payments = 3`
    - newest row `cash 40000`

Evidence:

- `build/mobile_client_finance_live.png`
- `build/mobile_client_finance_live_details.png`
- `build/ali_sale_result_for_reverse_restore.png`
- `build/delete_payment_confirm.png`
- `build/delete_payment_result_success.png`
- `build/restore_visible.png`
- `build/restore_payment_confirm.png`
- `build/restore_payment_result_success.png`

Local verification after the finance-write pass:

- `flutter analyze`: PASS
- `flutter test`: PASS

Important truth for this pass:

- collect payment was already wired from the audited `createTransaction` contract
- reverse and restore payment actions are now also wired from the exact working web payloads
- collect, reverse, and restore payment writes are now all cleanly Samsung-verified on a disposable client path

## 5. Safe Limits Kept

- No backend code changed
- No Firestore rules changed
- No indexes changed
- No schema changed
- Finance writes use only the already-audited `createTransaction` callable

## 6. Exact Remaining Blockers

1. The first finance-summary proof client had zero linked payment rows, so a richer historical finance client may still be worth checking later.
2. `flutter run` debug attach and some adb-driven route automation remain flaky because of the local device/debug tooling behavior.

## 7. Safe Next Actions

1. Keep using only the exact `createTransaction` payloads already proven in the web source.
2. Reuse the same disposable `ali vs` flow if a regression check is needed for payment reverse/restore.
3. Move on to the next write category after the finance payment loop is live-proven.
