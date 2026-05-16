## Purpose
Define the Google Play Store listing requirements: store copy, visual assets, content rating, and privacy policy.

## Requirements

### Requirement: Store listing SHALL have a valid title and descriptions
The Play Store listing MUST include:
- **Title**: `Expat8 – Learn English` (≤50 characters)
- **Short description**: a single sentence of ≤80 characters summarising the app's core value
- **Full description**: a description of ≤4000 characters covering key features, learning method, and target audience

#### Scenario: Title meets Play Store character limit
- **WHEN** the store listing title is submitted to Play Console
- **THEN** it is ≤50 characters and does not include placeholder text

#### Scenario: Short description is present and concise
- **WHEN** the short description field is reviewed in Play Console
- **THEN** it is ≤80 characters and communicates the swipe-based vocabulary learning concept

### Requirement: App icon SHALL meet Play Store icon specification
A high-resolution app icon MUST be provided as a 512×512 px PNG with no transparency (solid background), suitable for Play Store display.

#### Scenario: Icon passes Play Console upload validation
- **WHEN** the 512×512 px PNG icon is uploaded to Play Console
- **THEN** Play Console accepts it without validation errors

### Requirement: Feature graphic SHALL be provided
A feature graphic of exactly 1024×500 px MUST be provided for display in the Play Store app page header.

#### Scenario: Feature graphic dimensions are correct
- **WHEN** the feature graphic is uploaded to Play Console
- **THEN** it is accepted at 1024×500 px without errors

### Requirement: Phone screenshots SHALL demonstrate core app flows
A minimum of 2 phone screenshots MUST be provided showing the primary learning experience (vocabulary card and/or FITB card). Screenshots MUST be taken on a 16:9 or 19.5:9 aspect-ratio screen.

#### Scenario: At least two screenshots are uploaded
- **WHEN** the store listing is reviewed before publishing
- **THEN** at least 2 phone screenshots are present in the listing

### Requirement: Content rating SHALL be self-declared as Everyone
The app MUST complete the Play Console content rating questionnaire and receive an `Everyone` (ESRB) / `3+` (PEGI) rating. The app MUST NOT contain violence, explicit content, or public user-generated content.

#### Scenario: Content rating questionnaire completed
- **WHEN** the Play Console content rating section is opened
- **THEN** the rating is shown as `Everyone` (ESRB) or equivalent, with no pending questionnaire

### Requirement: Privacy policy SHALL be publicly accessible
A privacy policy URL MUST be provided in Play Console before the app can be published. The policy MUST disclose: device identifier collection, learning progress sync to backend, and audio recording permission usage (speaking drill feature).

#### Scenario: Privacy policy URL is reachable
- **WHEN** the privacy policy URL submitted to Play Console is fetched
- **THEN** it returns HTTP 200 and contains a readable privacy policy document
