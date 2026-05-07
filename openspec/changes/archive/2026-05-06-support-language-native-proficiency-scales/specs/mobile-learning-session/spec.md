## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where a downward swipe requests the next vocabulary card, and SHALL keep session navigation scoped to the active learning language and proficiency scale.

#### Scenario: User swipes down for next card
- **WHEN** the user performs a downward swipe on the learning screen
- **THEN** the app requests the next card using the active language and current scale-native proficiency state

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app restores session state including active language and associated proficiency scale metadata before continuing the session

### Requirement: Review scheduling updates after ratings
The mobile app SHALL allow the user to submit a memory rating and SHALL update local proficiency state from backend scale-native responses.

#### Scenario: User rates a card
- **WHEN** the user submits a rating for the current card
- **THEN** the app records the rating and applies returned `proficiency.scale`, `proficiency.level`, and `proficiency.level_index` to session state

#### Scenario: Proficiency level changes
- **WHEN** the backend reports a level change after rating submission
- **THEN** the app updates the displayed level label according to the returned scale without assuming CEFR-only semantics

## ADDED Requirements

### Requirement: Mobile renders proficiency labels by language scale
The mobile app SHALL render proficiency labels using language-native scale conventions.

#### Scenario: English session label
- **WHEN** the active learning language is English
- **THEN** the app renders CEFR labels such as A1 through C2

#### Scenario: Chinese session label
- **WHEN** the active learning language is Chinese
- **THEN** the app renders HSK labels such as HSK1 through HSK6
