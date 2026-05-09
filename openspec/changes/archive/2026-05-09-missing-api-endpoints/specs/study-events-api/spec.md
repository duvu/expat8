## MODIFIED Requirements

### Requirement: Idempotency and out-of-order handling
The backend SHALL handle duplicate submissions and out-of-order events correctly, recomputing proficiency thresholds from database. The batch sync response SHALL use the field names `accepted_event_ids` (array of newly accepted event keys), `rejected_events` (array of rejected event objects with `client_event_id`, `event_id`, and `reason`), and `duplicates` (array of event keys that were already recorded). The legacy field names `accepted` and `rejected` are removed.

#### Scenario: Duplicate submission doesn't double-count
- **WHEN** the same event is submitted twice via `POST /v1/study-events/sync`
- **THEN** backend recognizes it as duplicate, doesn't create a duplicate record, returns the event key in `duplicates`, and returns an empty `accepted_event_ids`

#### Scenario: Out-of-order events processed correctly
- **WHEN** a batch arrives with events that have mixed `occurred_at` timestamps
- **THEN** the backend processes them in chronological order and returns all event keys in `accepted_event_ids`

#### Scenario: Sync response uses correct field names
- **WHEN** `POST /v1/study-events/sync` processes a batch with one new event, one duplicate, and one invalid
- **THEN** the response contains `accepted_event_ids: [<new>]`, `duplicates: [<duplicate>]`, `rejected_events: [{ client_event_id, event_id, reason }]`, and `proficiency`

#### Scenario: Both event_id and client_event_id are accepted as event keys
- **WHEN** an event is submitted with only `event_id` (no `client_event_id`)
- **THEN** the backend uses `event_id` as the deduplication key and includes it in `accepted_event_ids`
