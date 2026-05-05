## MODIFIED Requirements

### Requirement: Session targets three new words and seven review words
The mobile app SHALL consume backend-selected learning card batches that target 15% new words and 85% review words, while local fallback may continue when backend refill is unavailable.

#### Scenario: Both new and review pools are available
- **WHEN** the app receives a backend-selected card batch with available new and review words
- **THEN** the app stores and displays cards according to the backend-provided card type metadata

#### Scenario: Target card type is unavailable
- **WHEN** the backend-selected batch contains fewer new or review cards than the target ratio
- **THEN** the app accepts the actual backend mix without blocking the session

### Requirement: Review scheduling updates after ratings
The mobile app SHALL allow the user to submit a memory rating, preserve the study event locally, and apply rating-specific local cache behavior.

#### Scenario: User rates a card
- **WHEN** the user submits a rating for the current card
- **THEN** the app records the rating, writes a study event, and writes a scheduling or completion log event

#### Scenario: User marks a card as forgotten
- **WHEN** the user rates a card as not remembered
- **THEN** the app keeps the word eligible for near-term review and logs the resulting schedule change

#### Scenario: User marks a card as easy
- **WHEN** the user rates a card as easy
- **THEN** the app removes the word from local vocabulary storage, preserves the study event for sync, and requests or displays a replacement card

## ADDED Requirements

### Requirement: Learning session refills replacement cards after easy ratings
The mobile app SHALL maintain session continuity after easy-rated local deletion by showing or requesting a replacement card.

#### Scenario: Replacement exists locally
- **WHEN** the user marks a card easy and another eligible local card exists
- **THEN** the app displays the replacement without waiting for backend refill

#### Scenario: Replacement requires backend refill
- **WHEN** the user marks a card easy and local eligible cards are below threshold
- **THEN** the app requests a backend-selected refill batch without losing the easy study event
