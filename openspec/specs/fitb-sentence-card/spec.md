## ADDED Requirements

### Requirement: Mobile renders fill-in-the-blank sentence cards for eligible review words
The mobile app SHALL render a fill-in-the-blank (FITB) variant of a review card when the word passes the eligibility guard, replacing the target word in the example sentence with a blank, and SHALL reveal the word and Vietnamese hint on a tap.

#### Scenario: Eligible review card is shown in FITB mode
- **WHEN** a review card has a non-empty `example` of at least 8 words containing the `term` (case-insensitive), and the `entry_type` is `word`, `phrase`, or `idiom`, and for `phrase`/`idiom` the `blank_word` field is non-null
- **THEN** the app renders the example sentence with the target word replaced by a blank (`___`) and hides the Vietnamese hint

#### Scenario: Learner taps the FITB card to reveal
- **WHEN** the learner taps anywhere on a FITB card
- **THEN** the app reveals the blanked word inline and shows the Vietnamese example translation and meaning

#### Scenario: Word entry type — term is used as blank target
- **WHEN** a FITB card has `entry_type == "word"`
- **THEN** the app blanks the entire `term` string within the `example` sentence (case-insensitive match)

#### Scenario: Phrase or idiom entry type — blank_word is used as blank target
- **WHEN** a FITB card has `entry_type == "phrase"` or `"idiom"` and a non-null `blank_word`
- **THEN** the app blanks the `blank_word` string within the `example` sentence (case-insensitive match)

#### Scenario: Ineligible card degrades to standard card
- **WHEN** a card fails any eligibility guard condition (example too short, term not found in example, or `blank_word` null for phrase/idiom)
- **THEN** the app renders the card in standard vocabulary card mode with no FITB treatment

### Requirement: FITB is applied to approximately fifty percent of total session cards
The mobile app SHALL apply FITB rendering to approximately fifty percent of the total learning session by activating FITB on review cards with a random threshold that accounts for the eighty-five percent review card share.

#### Scenario: Review card is selected for FITB
- **WHEN** a review card is being rendered and `Random().nextDouble() < 0.59`
- **THEN** the app uses `canFitb()` to decide whether to show the FitbCard or the standard card

#### Scenario: New card is never shown as FITB
- **WHEN** a card has `card_type == "new"`
- **THEN** the app renders the card in standard vocabulary card mode regardless of the FITB threshold
