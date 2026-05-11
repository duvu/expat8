## ADDED Requirements

### Requirement: Idioms are stored under synthetic language keys
Idiom entries SHALL be stored in the `words` table with a language key of the form `<base>-idioms` (e.g. `en-idioms`, `zh-idioms`). This makes idioms a fully independent study and exam track that reuses all existing language-keyed infrastructure without any backend routing changes.

#### Scenario: Idiom entry inserted with en-idioms language key
- **WHEN** a word is inserted with `language: 'en-idioms'` and `entry_type: 'idiom'`
- **THEN** the entry is stored successfully and is returned by `POST /v1/learning/cards` when `target_language: 'en-idioms'` is requested

#### Scenario: zh-idioms entries are isolated from zh entries
- **WHEN** a user requests learning cards with `target_language: 'zh-idioms'`
- **THEN** the response items SHALL only contain entries with `language = 'zh-idioms'`; no `language = 'zh'` entries appear

#### Scenario: Exam for en-idioms track uses only en-idioms entries
- **WHEN** `POST /v1/exam/start` is called with `language: 'en-idioms'`
- **THEN** all source words and distractors in the exam session are drawn exclusively from `language = 'en-idioms'` entries

### Requirement: Mobile language selector exposes idiom tracks
The exam language picker and learning language selector on mobile SHALL include `en-idioms` and `zh-idioms` as selectable options alongside the base language tracks.

#### Scenario: Language picker lists idiom track options
- **WHEN** the user opens the exam language picker
- **THEN** the picker includes at minimum: English (`en`), Chinese (`zh`), English Idioms (`en-idioms`), Chinese Idioms (`zh-idioms`)

#### Scenario: Selecting en-idioms starts an idiom-track exam
- **WHEN** the user selects "English Idioms" in the picker and taps Start Exam
- **THEN** `POST /v1/exam/start` is called with `language: 'en-idioms'`

### Requirement: Exam language picker persists last selection
The exam language picker SHALL persist the last-selected language across screen rebuilds and app restarts so users are not forced to re-select their preferred track every session.

#### Scenario: Language selection persists after navigation
- **WHEN** a user selects `zh-idioms` and navigates away from the exam screen
- **THEN** upon returning to the exam screen, the picker shows `zh-idioms` as the selected value

#### Scenario: First launch defaults to en
- **WHEN** no prior language preference has been stored
- **THEN** the picker defaults to `en`
