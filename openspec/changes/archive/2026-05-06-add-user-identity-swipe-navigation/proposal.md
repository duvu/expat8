## Why

The app currently treats each install as an anonymous device and uses the
learning screen as the only navigation surface. We need a user identity path
that lets learners optionally sign in for server-side progress tracking while
keeping anonymous usage intact, and we need to update the learning interaction
from pull-down refresh to explicit horizontal swipe gestures.

## What Changes

- Add optional user registration, sign-in, and sign-out support.
- Preserve anonymous learning for users who choose not to sign in.
- Allow anonymous learners to create a user account when they want server-side
  tracking.
- When signed in, associate learned words, study events, and proficiency state
  with the user on the backend.
- Keep device-based local learning and sync as the fallback path when signed
  out or offline.
- **BREAKING**: Replace the current downward swipe/pull-to-refresh next-card
  interaction with horizontal gestures:
  - right-to-left swipe requests a new word
  - left-to-right swipe requests review of recently learned words
- Add a left drawer menu to the mobile UI.
- Add a `Vocabulary` navigation item in the drawer.
- Add a bottom drawer action that shows `Sign in`/registration entry points
  when signed out and `Sign out` when signed in.
- Update backend/mobile API contracts and tests for optional user identity on
  word feed, study-event submission/sync, and proficiency lookup.

## Capabilities

### New Capabilities

- `user-identity-session`: Optional identity lifecycle, user registration,
  signed-in vs anonymous state, sign-in/sign-out behavior, and user-associated
  learning state.
- `mobile-navigation-shell`: Drawer menu structure, Vocabulary navigation item,
  and bottom sign-in/sign-out action.

### Modified Capabilities

- `mobile-learning-session`: Replace downward swipe with horizontal new/review
  gestures and define review of recently learned words.
- `mobile-local-cache-sync`: Preserve anonymous local learning while syncing
  signed-in study data to the server when identity is available.
- `backend-word-feed-sync`: Extend backend feed/sync behavior so requests can
  include optional user identity and backend tracking can use user-level state.

## Impact

- Affected mobile code: learning screen, controller card-selection API,
  repository identity state, backend API client, local database/session storage,
  widget tests, and navigation shell.
- Affected backend code: user identity model/endpoints, study-event persistence,
  word feed filtering/exclusion, proficiency lookup, and sync APIs.
- Affected API contracts: optional user identifier/session token on `/v1/*`
  learning requests, registration/sign-in/sign-out/session endpoints, and
  user-associated study event/proficiency responses.
- Affected data model: user table/session representation and user-linked study
  state while keeping `device_id` support.
- Dependency note: this change builds on the app credential and adaptive
  proficiency work currently present in the workspace; implementation should
  reconcile with `add-adaptive-proficiency-system` before coding.
