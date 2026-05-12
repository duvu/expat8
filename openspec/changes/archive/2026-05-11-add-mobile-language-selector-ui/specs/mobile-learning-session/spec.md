## MODIFIED Requirements

### Requirement: Swipe advances the learning session
The mobile app SHALL provide a primary learning screen where a downward swipe requests the next vocabulary card, SHALL show the current active learning language on that screen, and SHALL keep session navigation scoped to the selected learning language and proficiency scale.

#### Scenario: User swipes down for next card
- **WHEN** the user performs a downward swipe on the learning screen
- **THEN** the app requests the next card using the active language and current scale-native proficiency state

#### Scenario: App starts with local state
- **WHEN** the user opens the app
- **THEN** the app restores session state including active language and associated proficiency scale metadata before continuing the session

#### Scenario: User changes the active learning language
- **WHEN** the user selects a different learning language from the learning screen
- **THEN** the app reloads proficiency and subsequent card requests in the newly selected language

#### Scenario: Active language changes while a card is visible
- **WHEN** the user switches to another learning language while a card from the previous language is displayed
- **THEN** the app replaces that language context with content for the newly selected language instead of continuing the old one