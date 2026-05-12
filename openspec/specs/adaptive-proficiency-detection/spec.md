## Purpose
Define how the backend automatically adjusts a learner's proficiency level based on consecutive study-event ratings.

## Requirements

### Requirement: Auto-detect proficiency level from consecutive ratings

The system SHALL automatically increase the user's proficiency level by one step when the user provides 5 consecutive "Too Easy" ratings. The system SHALL automatically decrease the user's proficiency level by one step when the user provides 5 consecutive "Hard" ratings.

#### Scenario: Level increases after 5 consecutive "Too Easy"
- **WHEN** user is at proficiency level A1 and submits study event with "Too Easy" rating 5 times in a row
- **THEN** system increases proficiency level to A2 and returns `level_changed: true` in response

#### Scenario: Level decreases after 5 consecutive "Hard"
- **WHEN** user is at proficiency level B1 and submits study event with "Hard" rating 5 times in a row
- **THEN** system decreases proficiency level to A2 and returns `level_changed: true` in response

#### Scenario: Counter resets on different rating
- **WHEN** user has 3 consecutive "Too Easy" ratings and then submits "Easy" rating
- **THEN** counter for "Too Easy" resets to 0 and new counter for "Easy" begins

### Requirement: Enforce minimum and maximum proficiency levels

The system SHALL not allow proficiency to decrease below A1 or increase above C2.

#### Scenario: Cannot regress below A1
- **WHEN** user is at proficiency level A1 and submits "Hard" rating 5 times in a row
- **THEN** proficiency level remains at A1 and `level_changed: false` in response

#### Scenario: Cannot advance above C2
- **WHEN** user is at proficiency level C2 and submits "Too Easy" rating 5 times in a row
- **THEN** proficiency level remains at C2 and `level_changed: false` in response

### Requirement: Detect consecutive ratings accurately

The system SHALL recompute consecutive rating count from recent study events on each submission, not relying on client-provided counters.

#### Scenario: Server recomputes consecutive count from database
- **WHEN** backend receives study event submission with rating
- **THEN** system queries last 10 study events for the device, counts consecutive same ratings, and determines if threshold (5) is met

#### Scenario: Out-of-order submissions handled correctly
- **WHEN** two study event submissions arrive out of order due to network retry
- **THEN** system deduplicates by event ID and recomputes count correctly without double-counting
