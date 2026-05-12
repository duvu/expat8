## Purpose
Define how content packs are versioned so mobile clients can fetch only new or updated published content.

## ADDED Requirements

### Requirement: Content packs are versioned for incremental sync
The system SHALL expose content-pack versions so mobile clients can fetch only new or updated published content.

#### Scenario: Client requests content pack list
- **WHEN** client calls `GET /v1/content-packs` with last known version marker
- **THEN** the system returns available versions newer than the marker with metadata for download decisions

#### Scenario: Client downloads selected pack
- **WHEN** client calls `GET /v1/content-packs/:id` for an accessible pack
- **THEN** the system returns pack payload containing vocabulary entries and identifiers needed for local merge

### Requirement: Only approved published content appears in packs
The system SHALL include only approved and published vocabulary items in content-pack payloads.

#### Scenario: Item is pending review
- **WHEN** vocabulary item status is pending or rejected
- **THEN** it is excluded from pack generation output

#### Scenario: Item becomes approved and published
- **WHEN** reviewer approval and article publish complete
- **THEN** the item becomes eligible in subsequent pack versions
