## Purpose
Define the dedicated workplace sentence learning flow in the mobile app.
## Requirements
### Requirement: Mobile provides a dedicated workplace sentence study section
The mobile app SHALL expose a separate study section for common workplace English sentences and SHALL NOT mix sentence cards into the existing vocabulary learning session.

#### Scenario: Learner opens sentence study
- **WHEN** the learner enters the sentence study section
- **THEN** the app opens a sentence-only study flow backed by local workplace sentence inventory

### Requirement: Bundled starter sentences are available immediately
The mobile app SHALL import a bundled starter pack of 150 curated workplace English sentence cards into local storage before the first sentence study session requires network access.

#### Scenario: First use while offline
- **WHEN** the learner opens the sentence section on a fresh install while offline
- **THEN** the app imports the bundled starter sentences and displays a local sentence card without waiting for backend availability

#### Scenario: Starter pack was already imported
- **WHEN** the learner reopens the sentence section after the starter pack was previously imported
- **THEN** the app reuses the existing local sentence inventory and does not duplicate starter sentence records

### Requirement: Sentence study stays local-first during background refill
The mobile app SHALL serve visible sentence cards from local storage and SHALL trigger remote refill only in the background when local sentence inventory falls below a configured threshold.

#### Scenario: Low inventory while online
- **WHEN** local workplace sentence inventory drops below the refill threshold and network access is available
- **THEN** the app continues showing local sentence cards immediately and starts a background refill request without blocking navigation

#### Scenario: Refill fails while local sentences remain
- **WHEN** the sentence refill request times out or the backend is unavailable while local sentence cards still exist
- **THEN** the app continues the sentence study flow from local inventory and does not show a blocking empty-state error

### Requirement: Sentence cards display required learning content
The mobile app SHALL render each workplace sentence card with the English sentence text and Vietnamese meaning, and SHALL show optional topic or source metadata when available.

#### Scenario: Complete sentence card is shown
- **WHEN** a workplace sentence card includes text, translation, and topic metadata
- **THEN** the app displays the English text and Vietnamese meaning as required content and the topic metadata as supplemental context

