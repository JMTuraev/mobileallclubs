# Mobile Role Permissions Matrix

Status: Exact permissions blocked by missing production source

## What Is Confirmed

- The task brief defines two mobile roles of interest: `OWNER` and `STAFF`.
- The current repository does not contain the production role-resolution code, website route gating, Firestore rules, or backend permission logic required to derive exact permissions.
- No owner or staff capability should be widened or narrowed without audited code evidence.

## Confirmed Code Evidence In This Workspace

- No role models
- No auth flows
- No route guards
- No Firestore rules
- No Cloud Functions
- No web menus or feature gating

## Provisional Validation Matrix

This table is a validation checklist, not audited truth.

| Capability area | Owner access | Staff access | Audited evidence | Final status |
| --- | --- | --- | --- | --- |
| Sign in | Unknown | Unknown | No production auth flow present | Blocked |
| Gym resolution | Unknown | Unknown | No production resolver present | Blocked |
| Dashboard visibility | Unknown | Unknown | No production dashboard present | Blocked |
| Client read access | Unknown | Unknown | No client module present | Blocked |
| Client mutation access | Unknown | Unknown | No client mutation code present | Blocked |
| Package activation | Unknown | Unknown | No package workflow present | Blocked |
| Package renewal | Unknown | Unknown | No package workflow present | Blocked |
| Session start | Unknown | Unknown | No session workflow present | Blocked |
| Session end | Unknown | Unknown | No session workflow present | Blocked |
| Finance read access | Unknown | Unknown | No finance module present | Blocked |
| Finance write access | Unknown | Unknown | No finance mutation path present | Blocked |
| Analytics read access | Unknown | Unknown | No analytics module present | Blocked |
| Staff management | Unknown | Unknown | No staff module present | Blocked |
| Gym settings | Unknown | Unknown | No settings module present | Blocked |
| SaaS billing visibility | Unknown | Unknown | No billing module or backend present | Blocked |
| SaaS billing purchase action | Unknown | Unknown | No billing module or backend present | Blocked |
| Bar or POS access | Unknown | Unknown | No POS module present | Blocked |

## Sensitive Actions Requiring Explicit Audit

The following must be proven from real source before they are exposed on mobile:

- any staff creation, edit, removal, or invite flow
- any billing plan change or purchase flow
- any financial adjustment or reversal
- any subscription override or status change
- any session-force-close action
- any void, refund, or bar settlement action
- any settings screen that affects gym-wide configuration

## Screens Potentially Hidden From Staff

Not auditable yet. The brief suggests that the following may be owner-only, but this is not code-proven:

- SaaS billing
- staff management
- parts of finance
- some settings areas

## Safe Rule For Implementation

Until the real permission matrix is audited from production code:

- mobile may build role-aware infrastructure
- mobile may not assume final owner or staff access to any business module
- backend and Firestore permissions remain the only authority
