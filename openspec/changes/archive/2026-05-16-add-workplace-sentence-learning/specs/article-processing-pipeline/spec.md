## MODIFIED Requirements

### Requirement: Enrichment output is validated before persistence
The system SHALL validate enrichment payloads for vocabulary and workplace sentence candidates for schema, language consistency, safety, and required fields before storing term, sense, article-term, or sentence records.

#### Scenario: Enrichment payload passes validation
- **WHEN** the worker receives enrichment output matching required schema and safety checks for vocabulary and workplace sentence candidates
- **THEN** the system persists normalized terms, senses, article-term links, and eligible workplace sentence candidate records

#### Scenario: Enrichment payload fails validation
- **WHEN** the worker receives malformed or low-confidence enrichment output for vocabulary or workplace sentence candidates
- **THEN** the system rejects the invalid portion for promotion and records validation failure details

## ADDED Requirements

### Requirement: Article processing produces workplace sentence candidates
The system SHALL extract or generate workplace-useful English sentence candidates asynchronously from uploaded articles when the article content is eligible for sentence learning.

#### Scenario: Article contains eligible workplace sentences
- **WHEN** the worker processes an English article with usable workplace communication content
- **THEN** the system stores workplace sentence candidates linked to the source article for later learner serving

#### Scenario: Article yields no sentence candidates
- **WHEN** the worker processes an article that does not produce any valid workplace sentence output
- **THEN** the system completes article processing without failing the article solely because no sentence candidates were produced
