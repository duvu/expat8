## Context

The current mobile learning flow still exposes button-based actions and a legacy swipe mapping that does not match the intended product behavior. The app uses local-first storage, and user interactions in sessions are expected to read/write local data immediately, then sync with backend policies. Product direction requires a gesture-only UI, explicit local-state transitions for difficult/remembered signals, and predictable cache health through a daily refill policy.

The backend already provides learning feed APIs, but release operations must consistently publish tagged images to `docker.x51.vn` and redeploy from `~/deployment/worker-z440`.

## Goals / Non-Goals

**Goals:**
- Replace learning action buttons with gesture-only interactions.
- Define deterministic gesture-to-intent mapping with local database-backed state updates.
- Keep local cache capped at 1000 words.
- Add daily refill rule: if unlearned words < 100, fetch 100 words from backend.
- Ensure backend and Android release workflows are captured as requirements for rollout.

**Non-Goals:**
- Changing the spaced-repetition algorithm fundamentals outside the new remembered/difficult handling.
- Introducing server-side personalization tied to authenticated user profiles in this change.
- Replacing ObjectBox with another local storage engine.

## Decisions

1. Gesture-only interaction model on learning card
- Decision: Remove visible rating/action buttons and route all card actions from 4 directional gestures.
- Rationale: Reduces UI clutter and aligns with swipe-first learning ergonomics.
- Alternatives considered:
  - Keep buttons as fallback: rejected because it keeps dual behavior and increases inconsistency.
  - Add gesture hints only with existing buttons: rejected because it does not enforce single interaction model.

2. Local-first state transition on every gesture
- Decision: Every swipe action updates local database entities before any background sync.
- Rationale: Guarantees immediate UX response offline and preserves deterministic replay of user activity.
- Alternatives considered:
  - Server-first mutation: rejected due to latency/offline failure risk.

3. Cache policy with low-watermark daily top-up
- Decision: Maintain 1000-word cap and perform daily refill check; if unlearned count is below 100, request exactly 100 additional words.
- Rationale: Prevents session starvation while keeping local storage bounded.
- Alternatives considered:
  - Continuous refill on every session event: rejected due to noisy network behavior and unpredictable batching.
  - Much larger top-up batches: rejected due to local churn and increased duplicate handling complexity.

4. Deployment and release discipline
- Decision: Backend release requires tagged image build/push and worker-z440 compose redeploy; mobile release requires Android release build and deployment validation.
- Rationale: Avoids local-stack false positives and ensures production path is reproducible.

## Risks / Trade-offs

- Gesture discoverability risk for new users → Mitigation: provide lightweight onboarding hint/overlay and analytics for first-session gesture completion.
- Incorrect gesture classification on low-end devices → Mitigation: use threshold-based recognizers with unit/widget tests for edge cases.
- Daily refill may pull duplicates or unusable entries → Mitigation: de-duplicate by server/local IDs and enforce local insertion guards.
- Release pipeline drift between local and worker-z440 stacks → Mitigation: codify worker-z440 deploy path and verify runtime image tag post-redeploy.

## Migration Plan

1. Ship backend support and mobile code in feature branch; validate backend tests and mobile tests.
2. Build and push backend image with timestamp tag to `docker.x51.vn/x-ai/expat8-backend:<tag>`.
3. Update `~/deployment/worker-z440/docker-compose.yml` to new tag and force-recreate `expat8-backend`.
4. Build Android release artifact and validate gesture flows on emulator/device.
5. Monitor backend request logs for `/v1/learning/cards` and mobile telemetry for gesture events.

Rollback:
- Revert worker-z440 compose image tag to previous known-good backend image and recreate container.
- Redeploy previous Android build if gesture rollout causes critical usability regressions.

## Open Questions

- Should we expose configurable percentages (15%/10%) from remote config or keep compile-time defaults?
- Do we need explicit “undo last gesture” support for accidental swipes in v1?
- Should difficult-group review be strictly bounded per session window or adaptive to backlog size?
