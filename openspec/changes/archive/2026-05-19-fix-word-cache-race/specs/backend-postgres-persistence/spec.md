## ADDED Requirements

### Requirement: Word-cache replacement is idempotent under concurrent calls

The backend SHALL handle concurrent `PUT /v1/user-word-cache` requests for the same device without returning a 500 error. When two requests race, the final state SHALL contain all word ids submitted by either request.

#### Scenario: Two concurrent replacements with the same word ids
- **WHEN** two requests call `PUT /v1/user-word-cache` for the same `device_id` simultaneously with an overlapping or identical list of word ids
- **THEN** both requests return `200 OK` and no 500 error is produced; the `user_cached_words` table contains no duplicate rows for that device

#### Scenario: Sequential replacements succeed
- **WHEN** `PUT /v1/user-word-cache` is called once for a device and then called again before any other request
- **THEN** both calls return `200 OK` and the second call's word ids replace the first call's word ids in the store
