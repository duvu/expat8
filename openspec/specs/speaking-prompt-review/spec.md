# speaking-prompt-review Specification

## Purpose
TBD - created by archiving change add-speaking-foundation. Update Purpose after archive.
## Requirements
### Requirement: System stores reviewed speaking prompts for vocabulary
The system SHALL store speaking prompts that are linked to a word sense and optionally linked to an article term.

#### Scenario: Approved prompt is available for learning
- **WHEN** a word sense has an approved speaking prompt
- **THEN** learning-card responses may include the prompt target text, Vietnamese hint, target phrase, pronunciation tip, common Vietnamese learner mistake, difficulty, and topic for mobile speaking practice

#### Scenario: Prompt is not approved
- **WHEN** a speaking prompt is `pending_review` or `rejected`
- **THEN** the prompt SHALL NOT be served to normal mobile learning sessions as an approved speaking target

### Requirement: Speaking prompt content follows beginner-friendly quality rules
The system SHALL support review of prompt quality fields so admins can approve prompts that are short, natural, and useful for spoken English practice.

#### Scenario: Prompt is too long for A1 or A2
- **WHEN** an admin reviews a prompt targeting A1 or A2 and the target text is too long for beginner speaking practice
- **THEN** the dashboard allows the admin to edit or reject the prompt before it can be approved

#### Scenario: Prompt includes Vietnamese learner support
- **WHEN** an admin reviews a speaking prompt
- **THEN** the dashboard displays editable Vietnamese hint, pronunciation tip, and common mistake fields for that prompt

### Requirement: Dashboard supports prompt approval workflow
The dashboard SHALL allow admins to list, edit, approve, and reject speaking prompts attached to vocabulary review items.

#### Scenario: Admin approves a prompt
- **WHEN** an admin edits a prompt and marks it approved
- **THEN** the system saves the updated prompt fields, stores the approved status, and makes the prompt eligible for mobile learning-card responses

#### Scenario: Admin filters prompt quality queue
- **WHEN** an admin opens the prompt quality queue
- **THEN** the dashboard can show prompts missing required speaking fields, prompts that are too long, and prompts awaiting review

