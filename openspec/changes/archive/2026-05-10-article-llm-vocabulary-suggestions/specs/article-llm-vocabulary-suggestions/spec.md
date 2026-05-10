## ADDED Requirements

### Requirement: Worker can request LLM suggestions from article chunks
The system SHALL split long article text into manageable chunks and SHALL use the configured LLM to suggest candidate words and phrases from each chunk.

#### Scenario: Short article is processed as one chunk
- **WHEN** an article is short enough to fit within the configured chunk threshold
- **THEN** the worker submits the article text as a single LLM suggestion request

#### Scenario: Long article is split into chunks
- **WHEN** an article exceeds the configured chunk threshold
- **THEN** the worker splits the article into multiple chunks and processes each chunk separately

### Requirement: LLM suggestions include classification and level metadata
The system SHALL request structured suggestions that include term or phrase text, classification, and proficiency level for each candidate item.

#### Scenario: LLM returns valid structured suggestions
- **WHEN** the worker receives a valid response for an article chunk
- **THEN** the response items include suggested term or phrase text, a classification value, and a level value

#### Scenario: LLM returns invalid suggestion output
- **WHEN** the worker receives malformed or incomplete suggestion output
- **THEN** the system rejects that chunk result and records the failure without persisting invalid items

### Requirement: Suggested article vocabulary is normalized before persistence
The system SHALL validate and normalize LLM-suggested words and phrases before storing them as article vocabulary.

#### Scenario: Suggested phrase is accepted
- **WHEN** a suggested phrase passes validation and normalization
- **THEN** the worker persists it with the generated classification and level metadata

#### Scenario: Suggested item fails validation
- **WHEN** a suggested item fails schema, language, or quality checks
- **THEN** the worker excludes it from persistence and records the rejection reason
