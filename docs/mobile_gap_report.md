# Mobile Gap Report

Status: Critical parity gap confirmed

## Summary

- Current mobile parity against the production AllClubs system is effectively `0` live business modules.
- The repository contains a Flutter scaffold and placeholder module artifacts, but not the production web/backend contracts required to turn those modules into real owner/staff workflows.
- Live placeholder navigation must not be treated as shipped functionality. It should be removed or hidden until real modules exist.

## Confirmed Gaps

| Area | Gap status | Exact blocker |
| --- | --- | --- |
| Auth and bootstrap | Critical | No Firebase Dart wiring, no production auth flow, no role or gym resolver |
| Dashboard | Critical | No audited web source or data contracts |
| Clients | Critical | No list/detail reads, searches, filters, or action contracts |
| Packages and subscriptions | Critical | No package catalog or mutation authority |
| Sessions | Critical | No check-in/start/end contracts or state machine |
| Finance | Critical | No ledger source or aggregate truth |
| Analytics | High | No backend aggregate documents or computation contract |
| Staff management | High | No permission or mutation rules |
| Settings | Medium | No role-aware settings source |
| Billing | Critical | No in-app purchase path or backend verification contract |
| Bar/POS | High | No evidence the module exists in source |

## Current Codebase Cleanup Requirement

The repo contains placeholder-only artifacts under:

- `lib/features/dashboard/`
- `lib/features/clients/`
- `lib/features/sessions/`
- `lib/features/more/`
- `lib/features/shell/`

These files may stay in code as scaffolding references, but they must not remain exposed in live navigation until backed by real contracts.

## Safe Next Steps

1. keep backend, database, website, and rules untouched
2. remove fake live module exposure from the app
3. preserve only an honest workspace blocker entry state
4. wait for real production source before implementing business flows

## Unblockers

Real implementation can resume only after receiving:

- website source
- backend or Cloud Functions source
- Firestore rules and indexes
- role-resolution logic
- gym-resolution logic
- billing verification flow if it already exists in production
