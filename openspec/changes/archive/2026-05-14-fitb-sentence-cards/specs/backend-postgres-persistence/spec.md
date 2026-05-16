## MODIFIED Requirements

### Requirement: Backend preserves vocabulary storage behavior
The backend SHALL preserve the existing vocabulary storage contract while using PostgreSQL, including the optional `blank_word` field for phrase and idiom entries.

#### Scenario: Word is persisted
- **WHEN** a vocabulary item is accepted for storage
- **THEN** the backend stores the term, normalized term, language, Vietnamese meaning, part of speech, IPA, Vietnamese-friendly pronunciation, example, example translation, difficulty, topics, generation source, `blank_word` (nullable), and timestamps in PostgreSQL

#### Scenario: Duplicate word is detected
- **WHEN** a vocabulary item has the same normalized term and language as an existing PostgreSQL row
- **THEN** the backend returns the existing word instead of creating a duplicate row

## ADDED Requirements

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
