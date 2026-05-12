## Purpose
Define how the backend filters vocabulary content based on the learner's current proficiency level.

## Requirements

### Requirement: Filter words by user proficiency level

The system SHALL filter vocabulary words based on the user's current proficiency level when selecting new learning cards.

#### Scenario: Word feed filters to current level
- **WHEN** client calls `POST /v1/learning/cards` for a learner whose current proficiency is B1
- **THEN** system returns only words with `difficulty_level='B1'`

#### Scenario: No exact match falls back to adjacent levels
- **WHEN** client requests words at proficiency level B1 but no B1 words are available
- **THEN** system falls back to returning words from B2 or A2 (adjacent levels)

### Requirement: Support CEFR difficulty levels

The system SHALL recognize and filter words by the following CEFR difficulty levels: A1, A2, B1, B2, C1, C2.

#### Scenario: All six CEFR levels are supported
- **WHEN** system is asked to filter by any of A1, A2, B1, B2, C1, C2
- **THEN** filtering works correctly for all levels

#### Scenario: Reject invalid difficulty levels
- **WHEN** client requests words with `proficiency_level=beginner` or other non-CEFR value
- **THEN** system returns HTTP 400 or auto-maps to canonical CEFR equivalent

### Requirement: Respect existing word exclusions

The system SHALL apply proficiency level filtering in addition to existing word exclusion logic (do not return already-studied words).

#### Scenario: Proficiency filter and word exclusion both applied
- **WHEN** user is at level B1 and has already studied words [id1, id2]
- **THEN** system returns a word with `difficulty_level='B1'` that is not in [id1, id2]

### Requirement: Cascade fallback strategy

The system SHALL use a defined fallback strategy if no words exist at the exact proficiency level.

#### Scenario: Fallback order
- **WHEN** no B1 words are available
- **THEN** system tries B2, then A2, then A1, then C1, C2 in that order until a word is found
- **THEN** returns the first available word and notes the fallback in response metadata (optional)

### Requirement: Support dynamic proficiency queries

The system MAY optionally support dynamic proficiency lookup per request (fetch current proficiency from database) instead of requiring client to provide it.

#### Scenario: Query with device_id
- **WHEN** client calls `POST /v1/learning/cards` with `device_id=<id>` and no explicit proficiency level
- **THEN** system looks up current proficiency for that device and applies filter automatically
