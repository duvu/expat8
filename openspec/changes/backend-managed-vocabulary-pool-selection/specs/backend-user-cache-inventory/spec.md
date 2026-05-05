## ADDED Requirements

### Requirement: Backend stores active mobile cache inventory
The backend SHALL store the active server word IDs currently cached on each learner device.

#### Scenario: Mobile reports cache inventory
- **WHEN** the mobile app sends its current local `server_word_id` list with a `device_id`
- **THEN** the backend stores the inventory for that device and learner context

#### Scenario: Inventory includes unknown words
- **WHEN** the submitted inventory includes word IDs that do not exist in backend vocabulary
- **THEN** the backend ignores those unknown IDs and stores the valid inventory

### Requirement: Cache inventory sync is bounded
The backend MUST cap cache inventory submissions to the supported local cache size.

#### Scenario: Inventory is within limit
- **WHEN** mobile submits up to 1000 server word IDs
- **THEN** the backend accepts the inventory payload

#### Scenario: Inventory exceeds limit
- **WHEN** mobile submits more than 1000 server word IDs
- **THEN** the backend rejects or truncates the inventory according to the documented API contract

### Requirement: Cache inventory is replaceable
The backend SHALL support replacing a device's active cache inventory with the latest mobile-reported list.

#### Scenario: Mobile removes an easy word locally
- **WHEN** mobile deletes a locally cached word after an easy rating and submits updated inventory
- **THEN** the backend no longer treats that word as actively cached on the device

#### Scenario: Mobile cache is pruned
- **WHEN** mobile prunes local storage and reports the updated cache inventory
- **THEN** backend cache inventory reflects the pruned local state

### Requirement: Cache inventory is advisory for selection
The backend SHALL use cache inventory for duplicate avoidance but SHALL NOT treat it as authorization or proof of study history.

#### Scenario: Cache inventory conflicts with study history
- **WHEN** cache inventory and study history disagree about a word
- **THEN** the backend preserves study history and uses cache inventory only for active duplicate avoidance
