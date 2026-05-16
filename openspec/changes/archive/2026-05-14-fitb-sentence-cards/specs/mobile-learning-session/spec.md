## ADDED Requirements

### Requirement: Review card rendering supports FITB mode
The mobile learning session SHALL pass `card_type` and FITB eligibility data to the card renderer, and SHALL activate FITB rendering for review cards according to the FITB activation probability.

#### Scenario: Review card reaches FITB eligibility check
- **WHEN** `LearningSessionController` selects a review card for display
- **THEN** the controller evaluates `canFitb()` and the random threshold before dispatching the card to the renderer

#### Scenario: FITB card does not consume an additional gesture
- **WHEN** a FITB card is displayed and the learner taps to reveal
- **THEN** the reveal consumes the tap without advancing to the next card; only a subsequent swipe advances the session
