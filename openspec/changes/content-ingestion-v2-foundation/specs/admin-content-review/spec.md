## ADDED Requirements

### Requirement: Admin users can manage article review lifecycle
The system SHALL provide admin-only APIs to transition article state through processing, review, and publish stages with auditability.

#### Scenario: Admin marks article for reprocess
- **WHEN** an admin calls `POST /v1/admin/articles/:id/reprocess`
- **THEN** the system enqueues a processing job and updates article status to `pending_processing`

#### Scenario: Admin publishes reviewed article
- **WHEN** an admin publishes an article that has reviewable vocabulary items
- **THEN** the system marks the article as `published` and makes approved vocabulary eligible for learner serving/content packs

### Requirement: Vocabulary review decisions are explicit and traceable
The system SHALL allow admin reviewers to approve, reject, or edit extracted vocabulary entries before publication.

#### Scenario: Reviewer approves extracted sense
- **WHEN** reviewer submits approval for a pending vocabulary item
- **THEN** the system records reviewer decision and changes item status to approved

#### Scenario: Reviewer rejects low-quality sense
- **WHEN** reviewer rejects a vocabulary item with reason
- **THEN** the system marks item rejected and excludes it from learner-facing selection
