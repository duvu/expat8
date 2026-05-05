## Why

Investigation on 2026-05-05 found that registration, sign-in, and horizontal swipe failures can complete or fail without visible user feedback. This makes the mobile app appear unresponsive: users cannot tell whether auth succeeded, why auth failed, which account is active, or why a swipe did not load a new/review card.

## What Changes

- Add explicit mobile auth feedback for register, sign-in, and sign-out:
  - loading state while the action is running
  - success message when the action completes
  - user-facing error message when the action fails
- Display signed-in user information in the mobile UI, using display name when available and falling back to identifier.
- Keep anonymous learning available when auth fails.
- Fix swipe failure state so failed new/review requests do not silently keep a stale card without explanation.
- Make horizontal swipe behavior easier to discover and debug with visible new/review actions or hints.
- Preserve existing signed backend credential behavior and optional user-session semantics.
- Add verification tasks for mobile tests, backend dependency install/test, and signed backend smoke checks.

## Capabilities

### New Capabilities

- `mobile-auth-feedback`: Mobile auth result UX, loading/error/success feedback, and signed-in user info display.
- `runtime-verification-readiness`: Local and deployed verification expectations for Flutter, backend dependencies, signed API smoke checks, and TLS/certificate validation.

### Modified Capabilities

- `mobile-learning-session`: Clarify horizontal swipe behavior, no-card/stale-card state handling, and discoverable new/review actions.
- `mobile-local-cache-sync`: Surface backend/local fallback outcomes enough for user feedback and diagnostics without blocking offline learning.

## Impact

- Affected mobile files: learning screen, drawer, controller auth methods, card gesture surface, repository result handling, telemetry, and mobile tests.
- Affected backend/dev workflow: backend dependency install verification, signed read-only smoke checks, and TLS chain validation.
- Affected documentation: investigation follow-up, mobile setup, and runtime verification notes.
- This change builds on `add-user-identity-swipe-navigation`, which is complete but not yet archived, and should avoid overwriting in-progress adaptive proficiency work.
