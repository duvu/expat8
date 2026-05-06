## MODIFIED Requirements

### Requirement: Mobile stores learning data locally
The mobile app SHALL store vocabulary items, local word state, study events, sync queue entries, and app settings in local persistent storage implemented with ObjectBox only.

#### Scenario: Vocabulary is saved locally
- **WHEN** the app receives or displays a vocabulary item
- **THEN** the app persists the item and its learning metadata locally via ObjectBox entities

#### Scenario: Study event is saved before sync
- **WHEN** the user submits a study rating
- **THEN** the app writes the study event locally via ObjectBox before attempting backend sync

## ADDED Requirements

### Requirement: SQLite backward compatibility is not supported
The mobile app MUST NOT read, migrate, or preserve legacy SQLite local data once ObjectBox storage is enabled for this change.

#### Scenario: Existing install has SQLite database file
- **WHEN** a user upgrades to a build containing ObjectBox-only storage
- **THEN** the app initializes ObjectBox local storage as the source of truth and ignores legacy SQLite data

#### Scenario: Startup initializes local persistence
- **WHEN** local persistence is initialized
- **THEN** the app does not execute SQLite schema creation or SQL migration logic
