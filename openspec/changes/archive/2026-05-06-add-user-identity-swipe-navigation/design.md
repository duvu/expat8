## Context

The mobile app currently starts directly on the Vocabulary learning screen and
uses a downward pull/refresh-style gesture to request the next card. Learning
state is primarily device-based: the app creates a stable `device_id`, stores
words and study events locally, and syncs events to the backend when available.

The backend already has a path for device-based study events, proficiency
tracking work is in progress, and the app credential layer protects public API
requests. This change introduces optional user identity without removing
anonymous usage, then uses that identity to attach learned words and study
history to a server-side user profile when the learner signs in.

## Goals / Non-Goals

**Goals:**

- Let users continue learning without signing in.
- Let users register, sign in, and sign out from the mobile app.
- Associate signed-in study events, learned words, and proficiency state with a
  backend user record.
- Keep existing device-based local learning as the offline and signed-out path.
- Replace downward next-card gesture with horizontal gestures:
  right-to-left for new words and left-to-right for recently learned review.
- Add a left drawer menu with `Vocabulary` navigation and a bottom sign-in or
  sign-out action.
- Keep the learning screen focused on the usable study experience rather than a
  marketing or onboarding page.

**Non-Goals:**

- Social login provider selection beyond a simple first identity mechanism.
- Password reset, account deletion, profile editing, billing, roles, or admin
  tooling.
- Multi-page content beyond the `Vocabulary` drawer item.
- Full multi-device conflict resolution beyond attaching future synced events
  to the signed-in user.
- Replacing app credential security; identity auth should layer inside it.

## Decisions

1. Model identity as optional session state layered after app credentials.

   App credentials answer whether the caller is an approved app. User identity
   answers who the learner is. The mobile client should keep app credential
   signing for all `/v1/*` calls and add a user session token only when signed
   in. Backend handlers should accept anonymous requests with `device_id` and
   signed-in requests with both `device_id` and user identity.

   Alternative considered: require login before learning. That would make
   server tracking simpler but conflicts with the requirement that users can
   choose not to log in.

2. Start with a simple backend-owned registration and identity mechanism.

   The first implementation should provide a small identity API that can
   register a user account, create a session for sign-in, and revoke the session
   on sign-out without introducing OAuth provider complexity. Registration must
   reject duplicate account identifiers and must not create a signed-in session
   unless the account is accepted. The contract should hide provider details
   from the learning flow so OAuth or magic-link sign-in can replace the first
   mechanism later.

   Alternative considered: implement Google/Apple sign-in immediately. That is
   likely the production direction for mobile, but it pulls in platform setup
   and provider credentials before the app has a basic account/session
   contract.

3. Keep device data and merge forward on sign-in.

   The app should not discard anonymous local learning when the user signs in.
   On sign-in, future sync requests should include user identity and device id.
   The backend can associate subsequent events with the user immediately and
   may attach existing device history to the user as a migration step.

   Alternative considered: upload all local state as a blocking sign-in merge.
   That maximizes continuity but can make sign-in slow and fragile. The first
   version should keep sign-in quick and let background sync reconcile pending
   events.

4. Replace pull-to-refresh with directional swipe intents.

   The learning screen should interpret right-to-left as "new word" and
   left-to-right as "review recently learned." This is more explicit than the
   current card-selection ratio when the learner wants control over the next
   type of card. Existing rating buttons remain available for memory feedback.

   Alternative considered: keep the 3-new/7-review automatic selector and only
   add buttons. That preserves the current behavior but does not satisfy the
   requested directional gesture model.

5. Use a standard left drawer navigation shell.

   The drawer should contain the `Vocabulary` destination and pin the identity
   action to the bottom. The first shell can support a single real page without
   inventing extra sections.

   Alternative considered: bottom navigation. Drawer better matches the
   requested left menu and leaves the learning surface uncluttered.

## Risks / Trade-offs

- Identity implementation scope grows into full auth product -> Keep the first
  change to session lifecycle and user-linked learning data only.
- Anonymous and signed-in state diverge -> Keep `device_id` on all requests and
  include `user_id` only when signed in, allowing server-side reconciliation.
- Gesture direction may be confusing -> Add tests and clear semantics in code;
  keep rating controls visible and avoid hidden-only actions.
- Review "recently learned" competes with scheduled review -> Define it as a
  separate query intent that prefers recently seen/rated local words and falls
  back to due review if needed.
- Active adaptive proficiency work overlaps backend study-event APIs -> Rebase
  implementation on top of the current `add-adaptive-proficiency-system` state
  and avoid overwriting its proficiency/rating changes.

## Migration Plan

1. Add user/session persistence to backend schema and store interfaces while
   keeping nullable user fields and existing device paths.
2. Add registration, sign-in, and sign-out endpoints plus mobile API
   client/session repository support.
3. Update study-event, proficiency, and word-feed requests to include optional
   user identity when signed in.
4. Update local database/settings to store session state separately from
   `device_id`.
5. Replace pull-to-refresh learning interaction with horizontal swipe handling.
6. Add the drawer shell with `Vocabulary` and bottom sign-in/sign-out action.
7. Update tests across backend API/store, mobile repository/controller, and
   widget UI behavior.

Rollback is to disable the sign-in entry point and return to device-only sync.
Database additions should be additive and nullable so existing anonymous data
continues to work.

## Open Questions

- Should the first registration mechanism use email/password, email magic link,
  anonymous server account upgrade, or a local demo account suitable for later
  provider swap?
- Should sign-out keep cached user-linked words visible locally, or clear only
  session credentials and keep vocabulary cache?
- How far back should "recently learned" review look: current session only,
  last N rated words, or a time window such as the last 24 hours?
