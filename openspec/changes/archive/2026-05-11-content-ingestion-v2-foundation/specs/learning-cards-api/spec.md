## Purpose
Define that learning card selection uses persisted vocabulary only and does not invoke LLM generation at card-serving time.

## ADDED Requirements

### Requirement: Learning card selection uses persisted vocabulary only
The system SHALL select and return learning cards from approved/processed persisted vocabulary and SHALL NOT invoke LLM generation in card-serving requests.

#### Scenario: Due review cards are available
- **WHEN** client requests `POST /v1/learning/cards` and due review cards exist for the learner
- **THEN** the system prioritizes due review cards in the returned batch

#### Scenario: Request path does not generate with LLM
- **WHEN** card request is executed
- **THEN** the system serves from stored data and returns without calling enrichment/generation providers

### Requirement: Card selection applies deterministic fallback policy
The system SHALL apply deterministic fallback behavior when ideal card mix is unavailable.

#### Scenario: Requested mix cannot be satisfied
- **WHEN** not enough due/new cards exist for the requested batch
- **THEN** the system returns fewer cards or configured fallback seed/general cards without erroring the request

#### Scenario: Recently assigned cards are excluded
- **WHEN** card selection computes candidate set
- **THEN** cards recently assigned/seen for the same learner are excluded according to policy window
