## ADDED Requirements

### Requirement: Exam questions carry a question_type field
Each question in an exam session SHALL include a `question_type` field with value `meaning_choice` or `sentence_context` so the mobile client can render the appropriate layout.

#### Scenario: Exam session response includes question_type per question
- **WHEN** `POST /v1/exam/start` returns an exam session
- **THEN** each object in the `questions` array includes a `question_type` field set to either `meaning_choice` or `sentence_context`

#### Scenario: meaning_choice questions have no sentence field
- **WHEN** a question has `question_type: 'meaning_choice'`
- **THEN** the question object does NOT include a `sentence` field (or it is null/absent)

#### Scenario: sentence_context questions include sentence and highlight
- **WHEN** a question has `question_type: 'sentence_context'`
- **THEN** the question object includes `sentence` (the full example sentence) and `highlight` (the target term to identify within the sentence)

### Requirement: sentence_context questions are assigned when an example sentence exists
The backend SHALL assign `sentence_context` as the question type for a question when the source word has a non-empty `example` field. Questions without an example sentence SHALL always be assigned `meaning_choice`.

#### Scenario: Entry with example may receive sentence_context
- **WHEN** `startExamSession` processes an entry with a non-empty `example` field
- **THEN** the resulting question MUST be assigned either `meaning_choice` or `sentence_context` (backend MAY randomize the assignment)

#### Scenario: Entry without example always receives meaning_choice
- **WHEN** `startExamSession` processes an entry with an empty `example` field
- **THEN** the resulting question MUST have `question_type: 'meaning_choice'`

#### Scenario: Both question types appear in the same exam session
- **WHEN** an exam session is created from a pool that includes entries with non-empty examples
- **THEN** the session SHALL include at least one `meaning_choice` question and at least one `sentence_context` question (provided the pool is large enough)

### Requirement: Mobile exam UI renders sentence_context layout
The mobile exam question widget SHALL render a distinct layout for `sentence_context` questions, showing the full example sentence with the target term visually highlighted above the four answer choices.

#### Scenario: sentence_context question shows sentence with term highlighted
- **WHEN** the exam screen displays a question with `question_type: 'sentence_context'`
- **THEN** the full `sentence` text is displayed and the `highlight` term is visually emphasized (e.g. bold or underlined)

#### Scenario: meaning_choice question shows term without sentence
- **WHEN** the exam screen displays a question with `question_type: 'meaning_choice'`
- **THEN** only the term is displayed as the question stimulus, with no sentence above the choices

#### Scenario: Both question types share the same answer-choice interaction
- **WHEN** the user taps a choice for either question type
- **THEN** the answer is submitted and evaluated identically to the existing exam flow (correct/incorrect feedback, advance to next question)
