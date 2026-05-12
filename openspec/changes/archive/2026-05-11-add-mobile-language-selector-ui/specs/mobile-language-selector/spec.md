## Purpose
Define that the mobile learning screen displays a visible language selector so the user can identify and change the active study language.

## ADDED Requirements

### Requirement: Learning screen shows the active language selector
The mobile app SHALL display a clearly visible language selector on the primary learning screen so the user can identify the current study language without opening secondary navigation.

#### Scenario: Active language is visible on entry
- **WHEN** the user opens the learning screen
- **THEN** the screen shows the current active learning language in a prominent selector control

#### Scenario: Selector offers supported languages
- **WHEN** the user activates the language selector
- **THEN** the app presents the supported learning languages as explicit choices with readable labels

### Requirement: Language selection persists across app restarts
The mobile app SHALL persist the user's selected learning language on the device and restore it when the app starts again.

#### Scenario: App relaunch restores last language
- **WHEN** the user previously selected a learning language and later reopens the app
- **THEN** the selector and learning session start in that same language

#### Scenario: Persisted value is not supported
- **WHEN** the stored language value is missing or no longer supported
- **THEN** the app falls back to its default learning language and continues normally