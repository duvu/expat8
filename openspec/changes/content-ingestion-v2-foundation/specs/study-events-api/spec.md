## MODIFIED Requirements

### Requirement: Idempotency and out-of-order handling
The backend SHALL treat each study event identifier as an idempotency key, SHALL classify sync outcomes as accepted/duplicate/rejected, and SHALL apply deterministic projection order for out-of-order arrivals.

#### Scenario: Duplicate submission doesn't double-count
- **WHEN** mobile app retries the same study event (same client_event_id or event_id)
- **THEN** backend recognizes it as duplicate, does not create a second event, and returns duplicate classification in sync response

#### Scenario: Out-of-order events processed deterministically
- **WHEN** events arrive out of sequence due to offline replay or retry
- **THEN** backend applies projection using deterministic ordering `(occurred_at, received_at, event_id)` to update SRS state consistently

#### Scenario: Unknown references are rejected without aborting batch
- **WHEN** a sync batch includes an event with unknown word reference
- **THEN** backend marks that event rejected with reason and continues processing other valid events in the same batch
