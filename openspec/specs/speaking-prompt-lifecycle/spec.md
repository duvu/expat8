## Purpose
Define the lifecycle of speaking prompts on the mobile client: wire field naming, sync triggers, stale prompt removal, wordSenseId mapping, and drill attempt counter accuracy.

## Requirements

### Requirement: Speaking prompt wire fields use canonical names without language suffix
The backend SHALL serialize speaking prompt fields as `pronunciation_tip` and `common_mistake` (without a `_vi` language suffix). The mobile client SHALL deserialize these exact field names.

#### Scenario: Backend response includes canonical field names
- **WHEN** the backend returns a speaking prompt via `GET /v1/speaking/prompts` or sync endpoint
- **THEN** the response object contains `pronunciation_tip` and `common_mistake` (not `pronunciation_tip_vi` or `common_mistake_vi`)

#### Scenario: Mobile deserializes pronunciation tip
- **WHEN** the mobile client parses a speaking prompt response
- **THEN** `SpeakingPromptItem.pronunciationTip` is populated from the `pronunciation_tip` field

#### Scenario: Mobile deserializes common mistake
- **WHEN** the mobile client parses a speaking prompt response
- **THEN** `SpeakingPromptItem.commonMistake` is populated from the `common_mistake` field

### Requirement: Speaking prompts are synced on app resume, not only at startup
The mobile client SHALL trigger a speaking prompt sync whenever the app returns to the foreground (resume lifecycle event), in addition to the initial startup sync.

#### Scenario: App starts cold
- **WHEN** the app is launched from a terminated state
- **THEN** `SpeakingPromptSyncService.syncIfNeeded` is called during initialization

#### Scenario: App resumes from background
- **WHEN** the app transitions from background to foreground
- **THEN** `SpeakingPromptSyncService.syncIfNeeded` is called to refresh prompts

### Requirement: Stale speaking prompts are removed during sync
When the mobile client processes a speaking prompt sync response, it SHALL delete any locally stored prompts whose `promptId` is not present in the server response.

#### Scenario: Server removes a prompt
- **WHEN** a prompt present in local storage is absent from the server sync response
- **THEN** the local prompt is deleted from ObjectBox during the sync operation

#### Scenario: Server returns the same prompts
- **WHEN** all locally stored prompts are present in the server response
- **THEN** no prompts are deleted; existing prompts are upserted with updated data

### Requirement: Synced speaking prompts map word_sense_id from server payload
When upserting speaking prompts received from the server, the mobile client SHALL map the `word_sense_id` field from the server response to the local `wordSenseId` property.

#### Scenario: Server payload includes word_sense_id
- **WHEN** the sync response contains a prompt with a non-null `word_sense_id`
- **THEN** the local ObjectBox record stores that value in `wordSenseId`

#### Scenario: Lookup by wordSenseId returns synced prompts
- **WHEN** `getByWordSenseId` is called with a `wordSenseId` that matches a synced prompt
- **THEN** the matching prompt is returned (not an empty result)

### Requirement: Drill attempt counter reflects actual completed prompts
The mobile client SHALL report the correct number of attempted prompts in drill summary events. The `_totalAttempts` counter SHALL be read after incrementing, and the read SHALL occur before the `onDrillCompleted` callback for the final prompt.

#### Scenario: Drill completes with N prompts
- **WHEN** a drill session completes after N prompt attempts
- **THEN** the `promptsAttempted` field in the `onDrillCompleted` payload equals N (not N+1)
