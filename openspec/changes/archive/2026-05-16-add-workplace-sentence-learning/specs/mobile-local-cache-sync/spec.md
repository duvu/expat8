## MODIFIED Requirements

### Requirement: Mobile stores learning data locally
The mobile app SHALL store vocabulary items, workplace sentence items, local word state, local sentence state, study events, sync queue entries, and app settings in local persistent storage implemented with ObjectBox only.

#### Scenario: Vocabulary is saved locally
- **WHEN** the app receives or displays a vocabulary item
- **THEN** the app persists the item and its learning metadata locally via ObjectBox entities

#### Scenario: Workplace sentence is saved locally
- **WHEN** the app imports a bundled workplace sentence or receives a sentence item from backend refill
- **THEN** the app persists the sentence item and its local learning metadata locally via ObjectBox entities

#### Scenario: Study event is saved before sync
- **WHEN** the user submits a study rating
- **THEN** the app writes the study event locally via ObjectBox before attempting backend sync

## ADDED Requirements

### Requirement: Mobile maintains a dedicated workplace sentence cache
The mobile app SHALL seed workplace sentence inventory from bundled starter data and SHALL expand that inventory from backend refill batches without blocking visible study.

#### Scenario: Starter pack imports on first sentence study
- **WHEN** the learner opens the workplace sentence section for the first time
- **THEN** the app imports the bundled starter sentences before selecting the first local sentence card

#### Scenario: Sentence refill merges unseen items
- **WHEN** a background sentence refill succeeds
- **THEN** the app merges unseen sentence items into the local sentence inventory without blocking sentence navigation

#### Scenario: Sentence refill fails
- **WHEN** sentence refill fails due to timeout, network loss, or backend error
- **THEN** the app keeps the existing local sentence inventory and allows sentence study to continue

### Requirement: Mobile bounds workplace sentence inventory
The mobile app MUST retain no more than 1000 workplace sentence items in local storage, preserving bundled starter items until eligible non-starter items have been pruned first.

#### Scenario: Remote sentence batch arrives at cap
- **WHEN** the local workplace sentence inventory is at or above the configured cap and a new remote batch arrives
- **THEN** the app prunes the oldest eligible non-starter sentence items before inserting the new batch

#### Scenario: Only starter sentences remain
- **WHEN** the local workplace sentence inventory contains only bundled starter sentence items at the configured cap
- **THEN** the app defers additional remote sentence insertion until removable non-starter items become available
