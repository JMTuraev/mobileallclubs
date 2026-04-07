# Mobile Billing Architecture

Status: Architecture defined, implementation blocked on backend audit

## Scope Boundary

This document covers SaaS subscription billing for gym access to AllClubs inside the native mobile app. It does not cover gym operational transactions charged to the gym's own clients.

## Ownership

- Billing actions are assumed to be owner-only until production code proves otherwise.
- Staff access to billing must remain blocked unless explicit audited evidence shows parity.

## Core Truth Model

- Device purchase result is not canonical truth.
- Store verification plus backend entitlement state is canonical truth.
- Web and mobile must read the same entitlement source.
- Mobile must never treat a successful store callback as final activation without backend confirmation.

## Required Purchase Flow

1. Load store products from Google Play or the App Store.
2. Allow the owner to initiate a plan purchase from a billing screen.
3. Complete the native store purchase flow on device.
4. Send purchase evidence to the backend verification path.
5. Wait for backend verification and canonical entitlement update.
6. Render entitlement state from the shared backend truth.

## Required Restore Flow

1. Owner taps Restore Purchases.
2. App requests restore from the platform store.
3. Restored transactions are forwarded to backend verification.
4. Shared entitlement truth is refreshed from backend.

## Platform Notes

### Android

- Use Google Play Billing through Flutter's official in-app purchase support.
- Use server-side verification for purchase token validation.

### iOS

- Use App Store native subscription purchase flow through Flutter's official in-app purchase support.
- Use server-side verification for transaction validation.

## Entitlement Source Of Truth

The entitlement store must be shared across web and mobile. Candidate examples might include a Firestore entitlement document or backend-generated access state, but this repository does not contain the actual implementation, so no document path is assumed here.

## Renewal, Cancellation, Grace, And Expiry

- Mobile reads canonical entitlement state from backend.
- Mobile may show informative labels for renewal or grace periods only when the backend already models them.
- Mobile must not derive long-term entitlement from local clock math alone.

## Verification Boundary

- Verification should be idempotent.
- Verification should tolerate duplicate callbacks and safe retries.
- Verification should be isolated from operational finance records used by gyms for their own customers.

## Current Blocker

The actual billing verification backend is not present in this workspace. Therefore:

- no billing contract can be audited
- no entitlement document path can be confirmed
- no backend change can be proposed yet with confidence

If the real backend later proves that a verification endpoint is missing, the smallest additive and backward-compatible option must be documented in `docs/mobile_blocked_backend_changes.md` and flagged as `REQUIRES HUMAN APPROVAL` before any protected infrastructure change is made.
