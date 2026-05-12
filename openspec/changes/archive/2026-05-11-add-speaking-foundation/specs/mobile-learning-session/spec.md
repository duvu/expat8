## MODIFIED Requirements

### Requirement: Vocabulary card displays required learning content
The mobile app SHALL display all required vocabulary fields on each card when the data is available and SHALL expose optional speaking practice content when an approved speaking prompt or fallback example is available.

#### Scenario: Complete vocabulary card is shown
- **WHEN** a vocabulary card is displayed
- **THEN** the card includes the term, Vietnamese meaning, Vietnamese-friendly pronunciation, IPA, example sentence, and Vietnamese example translation

#### Scenario: Optional part of speech is available
- **WHEN** a vocabulary item includes part of speech
- **THEN** the card displays the part of speech with the vocabulary term

#### Scenario: Optional speaking prompt is available
- **WHEN** a vocabulary card includes an approved speaking prompt
- **THEN** the card exposes a non-blocking speaking entry point with target text and Vietnamese hint for local speaking practice

## ADDED Requirements

### Requirement: Speaking entry points preserve swipe behavior
The mobile learning session SHALL keep speaking practice optional and SHALL NOT require speaking before the learner can continue normal card navigation.

#### Scenario: Learner skips speaking prompt
- **WHEN** a speaking prompt is available on the current card and the learner swipes to another card instead of opening it
- **THEN** the app advances through the existing local card-selection flow without recording a speaking attempt

#### Scenario: Speaking sync is pending
- **WHEN** speaking event sync is pending or in progress
- **THEN** the app still selects the next card locally without awaiting the speaking sync operation
