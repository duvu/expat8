## Purpose
Define the backend endpoint that exposes weekly speaking session summaries per learner.

## Requirements

### Requirement: Backend exposes weekly speaking summary endpoint

The backend SHALL expose `GET /v1/speaking/summary` that returns aggregated speaking metrics for the requesting device over the past 7 rolling days.

#### Scenario: Summary returned for authenticated device
- **WHEN** `GET /v1/speaking/summary` is called with valid device_id header
- **THEN** backend returns JSON with: `spoken_sentences` (count of speaking_recorded events in last 7 days), `retry_rate` (ratio of retried attempts to total attempts), `drill_sessions_completed` (count of speaking_drill_completed events), `period_days: 7`

#### Scenario: First-time device with no speaking data
- **WHEN** device has no speaking events in the past 7 days
- **THEN** backend returns zeroed summary: `{ spoken_sentences: 0, retry_rate: 0, drill_sessions_completed: 0, period_days: 7 }`

#### Scenario: Unauthenticated request rejected
- **WHEN** `GET /v1/speaking/summary` is called without device_id header
- **THEN** backend returns HTTP 401

### Requirement: Backend tracks first recording conversion metric

The backend SHALL be able to determine whether a device has ever submitted a `speaking_recorded` event, enabling first recording conversion analytics.

#### Scenario: First recording flag derivable from events
- **WHEN** analytics query asks "how many devices have at least one speaking_recorded event"
- **THEN** the study_events table and existing indexes allow this query to be answered efficiently (under 2 seconds at beta scale)

#### Scenario: First recording timestamp available
- **WHEN** `GET /v1/speaking/summary` is called
- **THEN** response includes `first_recording_at` (ISO timestamp of earliest speaking_recorded event for device, or null if none)

### Requirement: Backend provides speaking funnel event counts

The backend SHALL store and allow aggregation of all speaking funnel events to support beta analytics.

#### Scenario: All funnel event types accepted and stored
- **WHEN** mobile submits any of the following event types: `speaking_prompt_viewed`, `speaking_sample_played`, `speaking_recorded`, `speaking_retried`, `speaking_self_rated_clear`, `speaking_self_rated_hesitated`, `speaking_self_rated_could_not_say`, `speaking_drill_completed`
- **THEN** backend stores the event with metadata and returns it in `accepted_event_ids`

#### Scenario: Speaking events do not affect proficiency
- **WHEN** backend processes speaking event types
- **THEN** proficiency level and consecutive_count are NOT modified; speaking events are stored independently

### Requirement: Database has index supporting efficient speaking analytics

The backend database SHALL have an index on `(device_id, event_type, created_at)` in the study_events table to support weekly summary queries at beta scale.

#### Scenario: Weekly summary query runs within SLA
- **WHEN** `GET /v1/speaking/summary` is called for a device with up to 1000 speaking events
- **THEN** response is returned within 500ms (p95) due to index support
