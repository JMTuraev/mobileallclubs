# Mobile Release Plan

Status: Release sequencing defined, execution blocked at source-audit stage

## Stage 0: Workspace Unblock

This stage must complete before real feature delivery begins.

- bring the production website source into the workspace
- bring the backend or Cloud Functions source into the workspace
- add Firestore rules and indexes
- verify real auth, role, and gym-resolution contracts
- verify real billing verification ownership
- confirm standard Firebase bootstrap requirements for Android and iOS

Exit criteria:

- parity audit can cite real source files
- owner/staff permission boundaries are code-proven
- real reads and writes are known

## Stage 1: First Real Mobile Modules

Start only after Stage 0 completes.

- auth bootstrap
- role and gym resolution
- protected shell
- dashboard
- clients list and detail
- sessions

Exit criteria:

- no fake live routes remain
- at least three real business modules are wired from audited contracts
- owner/staff route visibility matches production

## Stage 2: Secondary Operational Modules

- packages and subscriptions
- finance
- analytics
- staff management
- settings
- passive client flows
- POS or bar flows if confirmed in source

Exit criteria:

- all audited operational modules outside billing are implemented or explicitly documented as blocked

## Stage 3: Billing And Release Hardening

- native store purchase flow
- backend entitlement verification reuse
- restore purchases
- hardening tests
- release readiness review

Exit criteria:

- store purchase does not become canonical truth without backend verification
- final gap report contains no silent omissions

## Current Status

Current repository can only complete Stage 0 documentation and placeholder cleanup.
It cannot begin Stage 1 safely because the required production source is not present.
