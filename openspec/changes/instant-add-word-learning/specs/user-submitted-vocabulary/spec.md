## MODIFIED Requirements

### Requirement: Backend accepts owner-scoped vocabulary submissions from mobile
The backend SHALL provide an authenticated mobile API for creating a user-submitted vocabulary request using the submitted term, target language, and learner identity context (`user_id` when signed in, otherwise stable `device_id`). The normal mobile add-word request SHALL resolve the term immediately in the same request.

#### Scenario: Signed-in learner submits a word
- **WHEN** the mobile app sends a valid signed request to create a submitted vocabulary item while a valid bearer session is present
- **THEN** the backend stores the learner-owned submission context, resolves the word in-request, and returns a terminal result for that submission attempt

#### Scenario: Anonymous learner submits a word
- **WHEN** the mobile app sends a valid signed request to create a submitted vocabulary item without a bearer session but with the stable anonymous `device_id`
- **THEN** the backend stores the submission under that device context and returns a terminal result for that attempt

#### Scenario: Required fields are invalid
- **WHEN** the request omits the submitted term, omits the target language, or uses an unsupported language value
- **THEN** the backend rejects the request with a validation error and does not create a submission record

### Requirement: Backend deduplicates repeated submissions consistently
The backend SHALL normalize submitted terms and avoid creating duplicate active submissions for the same owner and language, while also linking to an existing canonical word when one already exists.

#### Scenario: Matching terminal submission already exists
- **WHEN** the same owner submits the same normalized term and language after an earlier ready resolution already exists
- **THEN** the backend may return the existing ready submission record instead of creating another unresolved processing record

#### Scenario: Matching canonical word already exists
- **WHEN** a submitted normalized term and language already match an existing stored word in the canonical `words` inventory
- **THEN** the backend links the submission to that existing word and returns a terminal ready/existing resolution without creating a duplicate canonical word

### Requirement: Backend enriches submitted vocabulary asynchronously
The backend SHALL resolve normal mobile add-word submissions in-request instead of relying on a learner-visible asynchronous worker lifecycle.

#### Scenario: In-request enrichment succeeds
- **WHEN** the backend receives a submitted term that does not already exist canonically and AI enrichment returns a valid vocabulary item
- **THEN** the backend persists the canonical word, links the learner submission to that word, and returns a ready result in the same request

#### Scenario: In-request enrichment fails
- **WHEN** in-request AI enrichment fails validation, times out, or cannot produce a valid vocabulary item
- **THEN** the backend returns a terminal failure outcome for the submission instead of leaving the learner submission queued or processing for later polling

### Requirement: Backend exposes submission status and resolved word payloads
The backend SHALL provide a read API for the current learner's submitted vocabulary records, including the resolved canonical word payload for ready submissions.

#### Scenario: Learner fetches submission list
- **WHEN** the mobile app requests submitted vocabulary records for the current user/device
- **THEN** the backend returns only that owner's submissions ordered by newest first with status, timestamps, submitted term, and any available resolution metadata

#### Scenario: Ready submission is returned
- **WHEN** a submission has been resolved to a canonical word
- **THEN** the backend includes a resolved word object using the standard vocabulary fields required by mobile learning cards

#### Scenario: Failed submission is returned
- **WHEN** a submission is in failed state
- **THEN** the backend includes a failure reason suitable for learner-facing status display

### Requirement: Resolved submissions join the normal learning inventory
The backend SHALL persist successful user-submitted vocabulary in the canonical word tables so the word is part of the same long-term learning system as all other vocabulary.

#### Scenario: Submitted word is persisted canonically
- **WHEN** a user-submitted vocabulary item is enriched successfully
- **THEN** the resulting word is stored in the canonical word inventory with the standard uniqueness, timestamps, and `generation_source` metadata

#### Scenario: Learner later requests learning cards
- **WHEN** the learner continues using the normal learning-card flow after a submission has been resolved
- **THEN** the resolved canonical word remains eligible for the existing learning pipeline rather than requiring a separate custom-study endpoint
