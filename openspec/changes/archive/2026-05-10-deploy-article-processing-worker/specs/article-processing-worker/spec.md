## ADDED Requirements

### Requirement: Article processing is handled by a background worker
The system SHALL process pending article ingestion jobs through a dedicated background worker rather than in synchronous API requests.

#### Scenario: A queued article job is claimed
- **WHEN** an article has a `pending_processing` job in `article_processing_jobs`
- **THEN** the worker dequeues the job, marks it `processing`, and marks the article `processing`

#### Scenario: Worker persists extracted vocabulary
- **WHEN** the worker successfully extracts and enriches candidate terms from an article
- **THEN** it persists normalized terms, word senses, article-term links, and vocabulary review items

### Requirement: Article ingestion jobs are durable and retryable
The system SHALL preserve processing job state so failed article ingestion can be retried or dead-lettered without losing the article record.

#### Scenario: Temporary worker failure schedules retry
- **WHEN** the worker encounters a recoverable error while processing a job
- **THEN** the job remains retryable and the article processing state is not lost

#### Scenario: Unrecoverable processing failure is visible
- **WHEN** the worker cannot enrich or validate article vocabulary after retries are exhausted
- **THEN** the job is marked dead-lettered or failed and the article records processing error metadata

### Requirement: Article ingestion uses LLM-backed enrichment with validation
The system SHALL validate enrichment output before persisting article vocabulary and SHALL use the configured LiteLLM runtime when available.

#### Scenario: Valid enrichment is accepted
- **WHEN** the worker receives enrichment output that matches the required vocabulary schema
- **THEN** the worker accepts the item and stores it as article vocabulary

#### Scenario: Invalid enrichment is rejected
- **WHEN** the worker receives malformed or low-confidence enrichment output
- **THEN** the worker rejects the item and does not persist invalid vocabulary records
