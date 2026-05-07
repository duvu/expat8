## 1. Baseline and Coordination

- [x] 1.1 Review current `add-user-identity-swipe-navigation` implementation and confirm files touched by auth, drawer, and horizontal swipe behavior
- [x] 1.2 Review current `add-adaptive-proficiency-system` pending work and avoid overwriting proficiency-related changes
- [x] 1.3 Reproduce or document current auth no-feedback and swipe stale-card behavior with the existing app state

## 2. Auth Feedback State

- [x] 2.1 Add controller state for auth action in progress, latest auth success message, and latest auth error message
- [x] 2.2 Catch registration errors and map backend/network/TLS/timeout failures to user-facing messages
- [x] 2.3 Catch sign-in errors and map invalid credentials/backend/network/TLS/timeout failures to user-facing messages
- [x] 2.4 Catch sign-out errors while still clearing local session according to existing anonymous fallback behavior
- [x] 2.5 Ensure failed register/sign-in leaves the app in anonymous mode or previous valid session state

## 3. Auth UI

- [x] 3.1 Show visible success feedback after successful registration
- [x] 3.2 Show visible success feedback after successful sign-in
- [x] 3.3 Show visible confirmation after sign-out
- [x] 3.4 Show visible error feedback after register/sign-in/sign-out failures
- [x] 3.5 Disable duplicate register/sign-in submissions while auth is in progress
- [x] 3.6 Add signed-in user info to the drawer using display name with identifier fallback
- [x] 3.7 Verify stored session loaded on app start renders signed-in user info

## 4. Swipe and Card State

- [x] 4.1 Update learning request result handling so backend/local fallback miss is distinguishable from success
- [x] 4.2 Prevent stale `currentWord` from hiding no-card or retryable error state
- [x] 4.3 Add visible no-card/retry message when new-word request fails and no fallback card exists
- [x] 4.4 Add visible no-card/retry message when recent-review request fails and no fallback card exists
- [x] 4.5 Add visible New Word and Review actions or clear swipe hints on the learning screen
- [x] 4.6 Confirm and encode the intended swipe direction semantics in code comments/tests
- [x] 4.7 Record telemetry for new-word fallback hit, fallback miss, recent-review hit, recent-review miss, and auth outcomes

## 5. Mobile Tests

- [x] 5.1 Add controller tests for registration success, registration failure, sign-in success, and sign-in failure feedback state
- [x] 5.2 Add widget tests showing drawer user info after a session is active
- [x] 5.3 Add widget tests showing auth success and error messages
- [x] 5.4 Add controller tests for new-word fallback miss and recent-review fallback miss
- [x] 5.5 Add widget tests proving stale cards do not hide no-card/error feedback
- [x] 5.6 Add widget tests for visible New Word and Review actions or swipe hints

## 6. Runtime Verification

- [x] 6.1 Run or document `npm ci` before backend test execution when `node_modules` is missing
- [x] 6.2 Run backend tests with `npm test` after dependencies are installed
- [x] 6.3 Run `flutter test` when Flutter SDK is available, or document the exact blocker when unavailable
- [x] 6.4 Add or document a read-only signed deployed smoke check for `/health` and `/v1/words/recent`
- [x] 6.5 Add or document an unsigned protected endpoint check that expects rejection
- [x] 6.6 Validate TLS/certificate chain for `BACKEND_BASE_URL` with mobile-relevant clients or document platform-specific blocker

## 7. Documentation and OpenSpec Validation

- [x] 7.1 Update docs with auth feedback behavior, user info display, and swipe/no-card behavior
- [x] 7.2 Update investigation report or add follow-up notes with implemented fixes and remaining environment blockers
- [x] 7.3 Run `openspec validate fix-mobile-auth-feedback-and-swipe-state`
- [x] 7.4 Run `openspec status --change fix-mobile-auth-feedback-and-swipe-state` and confirm all artifacts/tasks are ready before apply/archive
