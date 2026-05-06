## Why

The current learning UI depends on explicit buttons and does not reflect the intended swipe-first interaction model for rapid study sessions. At the same time, local vocabulary replenishment policy needs to be formalized around a 1000-word cache with daily low-watermark top-up so users do not run out of cards.

## What Changes

- Replace learning action buttons with gesture-only controls on the learning screen.
- Map horizontal and vertical swipe directions to study intents:
  - Right-to-left swipe: move to another card with review-oriented weighting (15% learned words).
  - Left-to-right swipe: move to review/new-mix flow with 15% new-word weighting.
  - Bottom-to-top swipe: mark current word as remembered and reduce relearning frequency to 10%.
  - Top-to-bottom swipe: mark current word as difficult and add to relearn group.
- Ensure gesture-triggered user activities read and update data from local database state.
- Enforce local vocabulary storage policy at 1000 words.
- Add daily refill check: when unlearned local words drop below 100, fetch and append 100 new words from backend.
- Build and release backend and mobile Android artifacts aligned with the change.

## Capabilities

### New Capabilities
- `mobile-gesture-learning-controls`: Gesture-only learning interactions, swipe-to-intent mapping, and local-state transitions for remembered/difficult workflows.
- `mobile-release-android`: Android release packaging and verification flow for mobile deployment readiness.

### Modified Capabilities
- `mobile-learning-session`: Replace button-driven rating actions with gesture-driven actions and preserve session progression semantics.
- `mobile-local-cache-sync`: Update refill policy to daily low-watermark replenishment (threshold 100, batch 100) while preserving 1000-word cap behavior.
- `backend-word-feed-sync`: Support backend fetch patterns required by daily top-up batch requests from local-first mobile flow.
- `backend-container-deployment`: Publish and redeploy expat8 backend image for production rollout of the new behavior.

## Impact

- Mobile UI layer: learning screen gesture handling and removal of on-screen rating buttons.
- Mobile session logic: controller intent routing, card selection policy, and local word-state updates.
- Mobile data layer: local database queries/writes for remembered/difficult states and daily refill logic.
- Backend API usage: word-feed endpoints and batch retrieval contracts used by mobile refill worker.
- Deployment operations: backend container image build/push/redeploy and Android release build output.
