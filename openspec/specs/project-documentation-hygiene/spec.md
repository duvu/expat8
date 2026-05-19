# project-documentation-hygiene Specification

## Purpose
TBD - created by archiving change cleanup-docs. Update Purpose after archive.
## Requirements
### Requirement: Current documentation matches the live codebase
The project SHALL keep current-facing markdown documentation aligned with the implemented storage layer, API endpoints, mobile data-loading flow, feature labels, and security requirements.

#### Scenario: Current docs describe mobile storage
- **WHEN** a current-facing document describes the mobile local persistence layer
- **THEN** it MUST describe ObjectBox as the source of truth and MUST NOT present SQLite or sqflite as the active implementation

#### Scenario: Current docs describe card loading
- **WHEN** a current-facing document describes backend card loading or vocabulary refill
- **THEN** it MUST describe signed `POST /v1/learning/cards` requests and MUST NOT present `/v1/words/next` or `GET /v1/learning/cards` as supported active behavior

#### Scenario: Current docs describe mobile refresh internals
- **WHEN** a current-facing document describes mobile prefetch, refresh, or sync internals
- **THEN** it MUST use names and flows that exist in the current mobile codebase and MUST NOT reference removed workers or deleted repository methods as active components

#### Scenario: Current docs describe sentence study labels
- **WHEN** a current-facing document describes the sentence study entry point or screen title
- **THEN** it MUST use the current `Sentences` label when describing the user-facing UI and MAY retain `Workplace sentences` only when referring to historical implementation details or internal identifiers

### Requirement: Contradictory historical docs are removed or clearly excluded from current guidance
The project SHALL remove markdown documents whose main content contradicts current code unless the document remains necessary as explicit historical evidence and is clearly excluded from setup/API guidance.

#### Scenario: Historical doc mainly describes removed architecture
- **WHEN** a markdown document primarily describes removed APIs, removed storage, or removed mobile workers
- **THEN** the cleanup MUST delete the document or replace it with current guidance

#### Scenario: Historical mention is still accurate context
- **WHEN** a document mentions removed behavior only to state that it was removed or unsupported
- **THEN** the mention MAY remain if it cannot be mistaken for current implementation guidance

### Requirement: Review artifacts summarize completed and incomplete sentence work
The project SHALL produce a markdown review report that summarizes the sentence-label rename, bundled sentence expansion, Vietnamese copy cleanup, and any remaining follow-up work.

#### Scenario: Review report is generated
- **WHEN** the refinement work is reviewed for completion
- **THEN** the report captures what is complete, what remains unfinished, and the key follow-up items in markdown form

