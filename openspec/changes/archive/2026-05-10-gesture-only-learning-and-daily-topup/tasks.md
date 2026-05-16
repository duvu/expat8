## 1. Gesture-Only Learning UI

- [x] 1.1 Remove learning action buttons from the learning screen layout and keep only card content plus gesture surface.
- [x] 1.2 Implement four-direction swipe detection with stable thresholds for horizontal and vertical intents.
- [x] 1.3 Map right-to-left and left-to-right swipes to session navigation intents with 15% weighting rules.
- [x] 1.4 Map bottom-to-top and top-to-bottom swipes to remembered/difficult intents and trigger card transition.

## 2. Local Database Session Updates

- [x] 2.1 Add or update local word-state fields to represent remembered frequency reduction (10%) and difficult-group assignment.
- [x] 2.2 Persist every gesture action to local database before any network/sync call.
- [x] 2.3 Update card selection logic to read weighting and difficult-group data from local store.
- [x] 2.4 Ensure gesture-triggered flows remain functional when device is offline.

## 3. Daily Refill and Cache Policy

- [x] 3.1 Keep local vocabulary cap at 1000 words in all insertion paths.
- [x] 3.2 Implement daily refresh job that checks unlearned local count.
- [x] 3.3 Trigger backend top-up of 100 words when unlearned local count is below 100.
- [x] 3.4 Merge fetched words into local storage with de-duplication safeguards.

## 4. Backend API Alignment

- [x] 4.1 Verify `/v1/learning/cards` supports top-up batch requests up to 100 items.
- [x] 4.2 Ensure backend returns stable payloads consumable by local merge flow.
- [x] 4.3 Validate recent/bootstrap word feed behavior for local cache restoration up to 1000 items.
- [x] 4.4 Add or update backend tests covering batch top-up and no-state refill requests.

## 5. Observability and Safety

- [x] 5.1 Add structured logs/telemetry for gesture intents and local state transitions.
- [x] 5.2 Add telemetry for daily refill checks (threshold hit, fetched count, failures).
- [x] 5.3 Add guardrails for invalid gesture payloads and local persistence errors.

## 6. Mobile Test Coverage

- [x] 6.1 Add widget tests verifying no action buttons are rendered on learning screen.
- [x] 6.2 Add gesture tests for all four swipe directions and expected session outcomes.
- [x] 6.3 Add repository/database tests for remembered 10% frequency and difficult-group behavior.
- [x] 6.4 Add tests for daily refill condition (<100 unlearned) and 100-word top-up execution.
- [x] 6.5 Run full `flutter test` suite and resolve regressions.

## 7. Build and Deployment

- [x] 7.1 Build and push backend image `<YOUR_REGISTRY>/expat8-backend:<timestamp-tag>`.
- [x] 7.2 Update `~/deployment/worker-z440/docker-compose.yml` to new backend tag and force-recreate `expat8-backend`.
- [x] 7.3 Verify deployed backend health at `http://<INTERNAL_HOST>:18787/health` and confirm runtime image tag.
- [x] 7.4 Build Android release artifact from mobile project.
- [x] 7.5 Validate release build on emulator/device with gesture smoke checks and no runtime crash.
