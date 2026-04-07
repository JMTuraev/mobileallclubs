# Mobile Test Plan

Status: Current testing is limited to honest workspace bootstrap behavior

## What Can Be Tested Right Now

Because the production source is absent, the only safe automated test targets are:

- app boots successfully
- bootstrap state reflects the audited workspace blocker
- live placeholder navigation is not exposed
- blocker docs are referenced from the app state

## Current Automated Checks

- `flutter analyze`
- widget tests for the workspace setup screen
- bootstrap provider test for blocker state

## Deferred Test Areas Until Source Is Available

The following test suites are required later, but cannot be authored honestly from this repo yet:

- real auth bootstrap tests
- owner vs staff route access tests
- gym resolution tests
- dashboard data loading tests
- clients list/detail repository tests
- sessions repository and action tests
- finance and analytics source-of-truth tests
- billing verification tests

## Future Parity Checklist

For every feature implemented after Stage 0, verify:

- feature exists in production source
- route/component source is identified
- role visibility is code-proven
- read path is code-proven
- write path is code-proven
- backend remains authority
- mobile flow is covered by tests

## Current Limitation

No feature-complete parity test should be written until the production website/backend source enters the workspace. Otherwise the tests would validate guesses instead of production truth.
