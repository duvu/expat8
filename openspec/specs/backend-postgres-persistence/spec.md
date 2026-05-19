# backend-postgres-persistence Specification

## Purpose
Define the PostgreSQL-backed vocabulary persistence contract, including canonical word storage behavior and required schema fields.
## Requirements
### Requirement: Backend preserves vocabulary storage behavior
The backend SHALL preserve the existing vocabulary storage contract while using PostgreSQL, including the optional `blank_word` field for phrase and idiom entries.

#### Scenario: Word is persisted
- **WHEN** a vocabulary item is accepted for storage
- **THEN** the backend stores the term, normalized term, language, Vietnamese meaning, part of speech, IPA, Vietnamese-friendly pronunciation, example, example translation, difficulty, topics, generation source, `blank_word` (nullable), and timestamps in PostgreSQL

#### Scenario: Duplicate word is detected
- **WHEN** a vocabulary item has the same normalized term and language as an existing PostgreSQL row
- **THEN** the backend returns the existing word instead of creating a duplicate row

### Requirement: words table stores blank_word column
The backend PostgreSQL schema SHALL include a nullable `blank_word TEXT` column on the `words` table to support FITB sentence card rendering.

#### Scenario: Schema migration adds blank_word column
- **WHEN** the blank_word migration is applied to an existing database
- **THEN** the `words` table gains a nullable `blank_word TEXT` column with no default and all existing rows have null in that column

#### Scenario: New word with blank_word is persisted
- **WHEN** a vocabulary item with a non-null `blank_word` is accepted for storage
- **THEN** the backend stores the `blank_word` value alongside the other word fields

#### Scenario: Word without blank_word is persisted
- **WHEN** a vocabulary item with a null or absent `blank_word` is accepted for storage
- **THEN** the backend stores null in the `blank_word` column without error

### Requirement: Word-cache replacement is idempotent under concurrent calls

The backend SHALL handle concurrent `PUT /v1/user-word-cache` requests for the same device without returning a 500 error. When two requests race, the final state SHALL contain all word ids submitted by either request.

#### Scenario: Two concurrent replacements with the same word ids
- **WHEN** two requests call `PUT /v1/user-word-cache` for the same `device_id` simultaneously with an overlapping or identical list of word ids
- **THEN** both requests return `200 OK` and no 500 error is produced; the `user_cached_words` table contains no duplicate rows for that device

#### Scenario: Sequential replacements succeed
- **WHEN** `PUT /v1/user-word-cache` is called once for a device and then called again before any other request
- **THEN** both calls return `200 OK` and the second call's word ids replace the first call's word ids in the store

