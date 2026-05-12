## Purpose
Define the ObjectBox-based local persistence layer for mobile learning data including words, events, settings, and logs.

## Requirements

### Requirement: Mobile app MUST persist learning data using ObjectBox
The mobile app SHALL persist local words, study events, sync queue entries, app settings, and app logs in ObjectBox boxes managed by a single app-local ObjectBox store.

#### Scenario: ObjectBox store initializes on app startup
- **WHEN** the app starts and initializes local persistence
- **THEN** the app opens a single ObjectBox store and loads all persistence repositories from that store

#### Scenario: Local entities are written through ObjectBox
- **WHEN** the app saves or updates words, study events, sync queue entries, settings, or logs
- **THEN** the app writes data through ObjectBox entity operations without SQLite calls

### Requirement: Mobile app MUST enforce deterministic local query behavior with ObjectBox
The mobile app SHALL preserve deterministic retrieval semantics for new words and due review words when using ObjectBox indexes and queries.

#### Scenario: Request next new word
- **WHEN** the app requests the next new word
- **THEN** the app returns the most recent eligible new-word entity using ObjectBox query ordering equivalent to current product behavior

#### Scenario: Request next due review word
- **WHEN** the app requests the next due review word for a timestamp
- **THEN** the app returns the earliest eligible due review entity using ObjectBox query conditions and ordering equivalent to current product behavior

### Requirement: Mobile app MUST support local data hygiene in ObjectBox
The mobile app SHALL support log pruning and bounded local word retention using ObjectBox operations.

#### Scenario: Log pruning executes
- **WHEN** log pruning runs with max age and max entries constraints
- **THEN** the app removes expired or overflow log entities and reports the number of deleted entries

#### Scenario: Local word retention exceeds cap
- **WHEN** local word count exceeds the configured cap
- **THEN** the app removes oldest eligible entities while preserving pending sync payload integrity
