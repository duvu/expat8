## Context

The investigation in `docs/20260505-auth-swipe-investigation.md` found a runtime UX gap after `add-user-identity-swipe-navigation`: auth APIs exist and signed feed requests can work, but the mobile app does not surface auth success/failure, does not render active user info, and can make swipe failures look like no-ops by keeping the stale card visible.

The backend now requires app credential signing for `/v1/*`, and mobile signs requests. A signed read-only probe reached the deployed backend, while Node reported a TLS chain issue. This change should focus on mobile feedback and state correctness while adding operational verification so credential/TLS/dependency issues are visible during testing.

## Goals / Non-Goals

**Goals:**

- Give immediate visible feedback for register, sign-in, and sign-out success/failure.
- Show active user identity in the drawer or app chrome when signed in.
- Keep anonymous learning available when auth fails.
- Make horizontal swipe actions visibly deterministic: users can tell whether a new/review request ran, failed, or had no available card.
- Prevent stale-card rendering from hiding no-card or backend/local fallback failure states.
- Add tests for auth feedback, user info rendering, swipe failure state, and verification readiness.
- Document and automate backend dependency install/test and signed API smoke checks where practical.

**Non-Goals:**

- Changing backend user/session data model.
- Adding password reset, OAuth, Apple/Google sign-in, account deletion, or profile editing.
- Removing app credential signing.
- Solving full TLS deployment automation, beyond adding checks and documenting failure interpretation.
- Reworking the adaptive proficiency algorithm.

## Decisions

1. Add explicit controller/UI auth result state.

   Register, sign-in, and sign-out should expose loading, success, and failure messages to the UI. The UI should show feedback via SnackBar or equivalent visible message.

   Alternative considered: rely on drawer state changing to `Sign out`. That is too subtle and fails when the user expects a clear success/error response.

2. Render signed-in user info in the drawer.

   The drawer should show `displayName` when present and fallback to `identifier`. This uses data already present in `UserSession` and avoids adding backend fields.

   Alternative considered: only show user info in app bar. Drawer is the current identity surface, so it should be the first place to fix.

3. Make no-card state explicit instead of hiding behind stale `currentWord`.

   If a new/review request cannot return a word and no local fallback exists, the controller should update UI state so the user sees the failure/no-card message. The implementation can either clear `currentWord` or show a prominent message overlay on the existing card, but it must not silently keep the old card with no feedback.

   Alternative considered: keep stale card for continuity. That preserves layout but is indistinguishable from a broken swipe unless paired with visible feedback.

4. Add discoverable new/review controls alongside gestures.

   Horizontal gestures can remain, but visible buttons or hints should exist for accessibility, slower drags, and debugging. This also reduces ambiguity about whether right-to-left or left-to-right maps to new/review.

   Alternative considered: tune velocity only. That still leaves the interaction hidden and harder to test manually.

5. Keep offline fallback but stop swallowing diagnostics.

   Word feed failures can still fall back to local data, but the repository/controller should report fallback hit/miss and failure reason enough for UI messages and telemetry.

   Alternative considered: make backend errors fatal. That violates local-first behavior.

6. Treat runtime verification as part of the fix.

   The investigation found `flutter` missing locally and backend tests failing without installed dependencies. The change should include explicit verification steps for `npm ci`, `npm test`, `flutter test` when available, signed read-only API smoke checks, and TLS/cert-chain checks.

   Alternative considered: leave this as tribal knowledge. That would make regressions likely because the existing OpenSpec task list was marked complete despite runtime gaps.

## Risks / Trade-offs

- Auth error messages expose too much technical detail -> Map low-level exceptions to concise user-facing messages and keep detailed diagnostics in logs/tests.
- Clearing stale card is visually jarring -> Prefer a clear empty/error state or overlay; test that user sees feedback.
- Visible new/review buttons clutter the learning screen -> Keep controls compact and secondary to the card.
- Gesture direction remains ambiguous -> Add labels/hints and tests that encode the chosen product semantics.
- Runtime smoke checks create real users -> Keep deployed checks read-only unless using a dedicated test namespace/account cleanup path.
- TLS issue reproduces only in some clients -> Document platform-specific verification and capture exact certificate-chain results.

## Migration Plan

1. Implement auth state and UI feedback without changing backend contracts.
2. Render active session identity in drawer/app chrome.
3. Update swipe/no-card state handling and add visible new/review controls or hints.
4. Add telemetry/logging for auth outcomes and feed fallback outcomes.
5. Add focused mobile unit/widget tests.
6. Add or document backend/mobile verification commands and read-only signed smoke checks.
7. Run available tests and record any environment blockers.

Rollback is limited to hiding the new feedback UI and restoring prior gesture-only behavior; backend API contracts remain unchanged.

## Open Questions

- Product semantics: should "slide right" mean new word, or should current right-to-left-for-new behavior remain?
- Should no-card failure clear the old card or show a banner over the old card?
- Should auth failures be shown as SnackBar, dialog, inline form error, or a combination?
