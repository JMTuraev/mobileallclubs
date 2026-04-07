# Mobile UI System

Status: Approved for mobile-only implementation

## Design Principles

- Build for operational speed first.
- Keep the UI dense enough for staff workflows, but never cramped.
- Surface status and next action before decorative detail.
- Prefer obvious actions over hidden gestures.
- Preserve trust with stable patterns, clear confirmations, and authoritative state labels.

## Product Tone

- Premium B2B SaaS console
- Calm and fast under pressure
- Confident but not flashy
- Native-feeling on both Android and iOS

## Navigation Model

- Top level uses a role-aware shell with a small number of stable destinations.
- Primary modules should live in bottom navigation when the role has four or fewer high-frequency areas.
- Lower-frequency destinations should live under a More tab or settings stack, not as extra top-level tabs.
- Every feature stack should support deep linking and guarded entry.

## Information Hierarchy

- Page header: title, one-line context, high-priority action
- Summary band: status chips, counts, or alerts
- Main content: list, card group, form, or detail sections
- Secondary actions: contextual sheet or trailing overflow menu

## Typography Strategy

- Use strong size contrast between page titles, numeric KPIs, section labels, and dense metadata.
- Keep list rows compact with a clear primary line and muted secondary metadata.
- Reserve large display text for KPIs, totals, and urgent empty-state calls to action.

## Spacing And Density Rules

- Base spacing scale: 4, 8, 12, 16, 20, 24, 32
- Screen padding: 16 on phone, 20 on large phones
- Card padding: 12 to 16 depending on density
- Dense operational rows: minimum 56 height
- Tappable controls: minimum 44 logical pixels

## Color And Status System

- Neutral surfaces with strong contrast
- One clear brand accent for primary actions
- Status chips must map consistently across modules:
  - success or active
  - warning or expiring
  - error or blocked
  - info or draft
  - neutral or inactive
- Financial positive and negative states must be visually distinct without relying on color alone

## List And Card Adaptation Rules

- Replace large web tables with compact card rows or two-line list tiles.
- Put the most actionable information above fold:
  - client name
  - subscription state
  - visit balance
  - session state
  - amount and payment status
- Support search-first workflows with persistent query state.
- Use segmented controls for active versus passive or live versus history views.

## Form Patterns

- Full-screen form for multi-step create or edit flows
- Inline validation on blur and on submit
- Sticky primary action when the form is long
- Explicit review step for risky financial or subscription mutations

## Modal Versus Full-Screen Rules

- Use bottom sheets for quick filters, small pickers, and contextual actions.
- Use full-screen flows for package activation, renewal, staff edit, and any operation that needs review.
- Use confirmation dialogs only for clearly destructive or irreversible actions.

## Bottom-Sheet Rules

- Keep bottom sheets focused on one decision cluster.
- Prefer action lists with strong labels over icon-only layouts.
- Never hide the only critical action in a deep overflow path.

## Loading, Empty, And Error Patterns

- Loading states should preserve layout shape whenever possible.
- Empty states must explain why the list is empty and what the user can do next.
- Error states must distinguish retryable connection issues from permission failures and business-rule failures.
- Bootstrap failures should never drop the user into a half-rendered app shell.

## Role-Aware Behavior

- Shell destinations should reflect the resolved role.
- Hidden actions must also be backend-protected; UI hiding is only convenience.
- Owner-only zones should visually reinforce sensitivity without adding friction to normal use.

## Quick-Action Patterns

- Dashboard quick actions should be role-aware and limited to high-frequency operations.
- Client detail screens should group actions by purpose:
  - membership
  - session
  - finance
  - contact
- Session actions must prioritize speed and error prevention.

## Dense Operations Layout Rules

- Use section dividers, muted metadata, and status chips to avoid visual noise.
- Prefer short horizontal KPI bands over tall dashboard stacks.
- Keep high-frequency actions reachable with one thumb on typical phone sizes.
- Avoid nested tabs inside nested tabs.

## Accessibility And Safety

- Preserve text contrast and large-tap targets.
- Pair color-coded states with labels or icons.
- Confirm destructive or financially sensitive actions.
- Show authoritative timestamps and state labels when available.
