## Purpose
Define how the backend stores and retrieves a user's proficiency level per target language.

## Requirements

### Requirement: Store and retrieve user proficiency level

The system SHALL store the current proficiency level (A1–C2) per device and language. The system SHALL initialize new devices at proficiency level A1.

#### Scenario: New device starts at A1
- **WHEN** a device first submits a study event or requests proficiency
- **THEN** system creates a proficiency record with level A1 and returns it

#### Scenario: Retrieve current proficiency level
- **WHEN** client requests `GET /v1/proficiency?device_id=<id>`
- **THEN** system returns current level, last updated timestamp, and consecutive rating count toward next level change

#### Scenario: Proficiency persists across sessions
- **WHEN** user closes app, later reopens it, and requests proficiency
- **THEN** system returns the same level as before

### Requirement: Update proficiency level atomically

The system SHALL update proficiency level and timestamp in a single atomic transaction when a level change occurs.

#### Scenario: Level change committed atomically
- **WHEN** 5th consecutive "Too Easy" rating is submitted and level change is triggered
- **THEN** system atomically updates `user_proficiency.level` and `updated_at` in a transaction

### Requirement: Support multiple languages (scoped to English for MVP)

The system SHALL store proficiency per device per language. For MVP, only English (`language='en'`) is supported.

#### Scenario: Device can have different levels per language
- **WHEN** future feature adds support for multiple languages
- **THEN** each device has separate proficiency level for each language

#### Scenario: MVP defaults to English
- **WHEN** a new device is initialized or requests proficiency
- **THEN** default language is 'en' and level is set for that language
