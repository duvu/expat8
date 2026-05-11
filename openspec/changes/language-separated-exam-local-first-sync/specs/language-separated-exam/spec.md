## ADDED Requirements

### Requirement: Exam content is isolated by active language
The system SHALL generate and display exam content only from the active exam language. English exam sessions MUST NOT include Chinese terms, prompts, choices, or distractors, and Chinese exam sessions MUST NOT include English terms, prompts, choices, or distractors.

#### Scenario: English exam uses English-only content
- **WHEN** the user starts an exam with English as the active language
- **THEN** every question, answer choice, and result context shown in that session contains English content only

#### Scenario: Chinese exam uses Chinese-only content
- **WHEN** the user starts an exam with Chinese as the active language
- **THEN** every question, answer choice, and result context shown in that session contains Chinese content only

#### Scenario: Cross-language content is excluded from distractors
- **WHEN** the system generates distractors for a question in the active language
- **THEN** it excludes distractors from the other language

### Requirement: Exam flow respects the selected language end to end
The mobile exam flow SHALL preserve the active language from session start through question display and results display.

#### Scenario: Active language is preserved through the session
- **WHEN** the user starts an exam in one language and progresses through questions to the results screen
- **THEN** the results screen reflects the same active language and does not introduce content from another language
