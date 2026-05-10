## ADDED Requirements

### Requirement: Dashboard lists speaking prompts with filter and status

The admin dashboard SHALL provide a page at `/speaking-prompts` that lists all speaking prompts with filtering by status (pending_review, approved, rejected) and word sense.

#### Scenario: Admin views prompt list
- **WHEN** authenticated admin navigates to `/speaking-prompts`
- **THEN** dashboard displays a paginated table of prompts with columns: word_sense, target_text, difficulty, status, updated_at

#### Scenario: Admin filters by status
- **WHEN** admin selects a status filter (pending_review | approved | rejected)
- **THEN** table updates to show only prompts with that status

#### Scenario: Unapproved prompt count shown
- **WHEN** admin lands on the speaking prompts page
- **THEN** a badge or counter shows number of prompts with status `pending_review`

### Requirement: Admin can edit speaking prompt fields

The dashboard SHALL allow admins to edit speaking prompt content fields inline or via an edit form.

#### Scenario: Admin edits target_text and vi_hint
- **WHEN** admin opens edit form for a prompt
- **THEN** form shows editable fields: target_text, vi_hint, pronunciation_tip_vi, common_mistake_vi, difficulty (CEFR dropdown), topic

#### Scenario: Edit saved and timestamp updated
- **WHEN** admin submits the edit form
- **THEN** dashboard calls `PUT /v1/admin/speaking-prompts/:id` and shows updated row with new `updated_at`

#### Scenario: Empty required fields blocked
- **WHEN** admin clears `target_text` and attempts to save
- **THEN** form shows validation error and does NOT submit

### Requirement: Admin can approve or reject speaking prompts

The dashboard SHALL allow admins to change prompt status to `approved` or `rejected` with an optional rejection reason.

#### Scenario: Admin approves a prompt
- **WHEN** admin clicks "Approve" on a pending_review prompt
- **THEN** status changes to `approved`; prompt becomes eligible for mobile delivery

#### Scenario: Admin rejects a prompt
- **WHEN** admin clicks "Reject" and optionally enters a reason
- **THEN** status changes to `rejected`; prompt is excluded from mobile delivery

#### Scenario: Approved prompts visible to mobile
- **WHEN** mobile requests speaking prompts via API
- **THEN** backend returns only prompts with `status = 'approved'`

### Requirement: Backend exposes admin speaking prompt API

The backend SHALL expose authenticated admin routes for speaking prompt CRUD.

#### Scenario: List prompts endpoint
- **WHEN** `GET /v1/admin/speaking-prompts?status=pending_review` is called with valid app credentials
- **THEN** backend returns paginated list of prompts filtered by status

#### Scenario: Update prompt endpoint
- **WHEN** `PUT /v1/admin/speaking-prompts/:id` is called with valid payload
- **THEN** backend updates the prompt record and returns the updated object

#### Scenario: Unauthenticated request rejected
- **WHEN** request to admin prompt endpoints is missing app-credential headers
- **THEN** backend returns HTTP 401
