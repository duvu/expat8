## 1. Coordination and Baseline

- [x] 1.1 Review current `add-adaptive-proficiency-system` changes and identify overlapping backend study-event, proficiency, and mobile controller files.
- [x] 1.2 Rebase or sequence implementation so identity work preserves adaptive proficiency behavior and tests.
- [x] 1.3 Confirm current app credential signing remains required for all new identity and learning API calls.

## 2. Backend Identity Model

- [x] 2.1 Add backend schema support for users, user sessions, and user-linked learned-word or study state while preserving device_id paths.
- [x] 2.2 Extend backend store interfaces and PostgreSQL implementation for registering users, rejecting duplicate account identifiers, and creating/resolving sessions.
- [x] 2.3 Add backend tests for user registration, duplicate registration rejection, session persistence, and device-to-user association.
- [x] 2.4 Ensure sign-out/session revocation can invalidate future signed-in requests without deleting device records.

## 3. Backend Identity and Learning APIs

- [x] 3.1 Add registration endpoint protected by app credentials.
- [x] 3.2 Add sign-in/session creation endpoint protected by app credentials.
- [x] 3.3 Add sign-out/session revoke endpoint protected by app credentials.
- [x] 3.4 Add user session resolution middleware or helper for learning endpoints.
- [x] 3.5 Extend study-event submission and sync APIs to associate valid signed-in requests with user identity.
- [x] 3.6 Extend proficiency lookup to return user-level state when signed in and device-level state when anonymous.
- [x] 3.7 Extend new-word feed selection to avoid words already learned by the signed-in user when alternatives are available.
- [x] 3.8 Add backend API tests for registration success, duplicate registration rejection, anonymous requests, signed-in requests, invalid sessions, sign-out, and learned-word-aware feed behavior.

## 4. Mobile Identity State and API Client

- [x] 4.1 Add mobile user session model and local persistence separate from device_id.
- [x] 4.2 Add backend API client methods for registration, sign-in, and sign-out with app credential signing.
- [x] 4.3 Update repository/session services to expose registered/signed-in vs anonymous state.
- [x] 4.4 Include user session identity on eligible word feed, study-event, sync, and proficiency requests.
- [x] 4.5 Keep anonymous local learning functional when registration fails, sign-in fails, sign-out completes, or network is unavailable.
- [x] 4.6 Add mobile unit tests for registration success/failure, session persistence, request identity headers/payloads, and anonymous fallback.

## 5. Horizontal Learning Gestures

- [x] 5.1 Replace pull-to-refresh/downward next-card behavior with horizontal swipe detection on the learning card surface.
- [x] 5.2 Add controller methods for explicit new-word intent and recent-review intent.
- [x] 5.3 Implement right-to-left swipe to request a new word.
- [x] 5.4 Implement left-to-right swipe to request recently learned review.
- [x] 5.5 Add recent-review repository/local database query that prefers just-studied words and falls back to due review.
- [x] 5.6 Update telemetry events to distinguish new-word swipe and recent-review swipe.
- [x] 5.7 Add controller and widget tests for both swipe directions and fallback behavior.

## 6. Drawer Navigation Shell

- [x] 6.1 Add a left drawer to the main mobile scaffold.
- [x] 6.2 Add `Vocabulary` drawer item that opens/closes to the vocabulary learning screen.
- [x] 6.3 Add bottom drawer identity action area that exposes registration/sign-in when anonymous and `Sign out` when signed in.
- [x] 6.4 Wire registration action to create a user account and store the returned session on success.
- [x] 6.5 Wire Sign in action to the identity flow and refresh drawer/session state after success or failure.
- [x] 6.6 Wire Sign out action to clear the active user session and return to anonymous mode.
- [x] 6.7 Add widget tests for drawer opening, Vocabulary navigation, Register/Sign in display, and Sign out display.

## 7. Documentation and Contracts

- [x] 7.1 Update `contracts/api.md` with registration endpoint, identity endpoints, optional user session semantics, and signed-in learning request examples.
- [x] 7.2 Update product/technical docs to describe optional registration/login, anonymous mode, server-side learned-word tracking, and sign-out behavior.
- [x] 7.3 Update mobile setup docs if new auth configuration or test fixtures are required.
- [x] 7.4 Document horizontal swipe semantics and remove references to downward swipe as the primary next-card gesture.

## 8. Verification

- [x] 8.1 Run backend tests covering identity, feed, sync, proficiency, and app credential integration.
- [x] 8.2 Run mobile unit and widget tests for repository, controller, drawer, and swipe behavior.
- [x] 8.3 Run an end-to-end smoke flow for anonymous learning, registration, sign-in/session use, signed-in study tracking, sign-out, and anonymous continuation.
- [x] 8.4 Run `openspec validate add-user-identity-swipe-navigation`.
- [x] 8.5 Run `openspec status --change add-user-identity-swipe-navigation` and confirm all implementation tasks are complete before archive.
