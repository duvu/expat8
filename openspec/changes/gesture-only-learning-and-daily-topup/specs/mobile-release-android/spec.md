## ADDED Requirements

### Requirement: Mobile project SHALL produce Android release build
The mobile codebase MUST support Android release packaging that compiles the application with release profile and produces a distributable artifact.

#### Scenario: Operator builds Android release
- **WHEN** an operator runs the documented Android release build command
- **THEN** the build completes successfully and outputs a release APK or app bundle artifact

### Requirement: Release validation SHALL include gesture-based study flow
Before release publication, Android validation MUST verify the gesture-only learning workflow, including all four swipe directions and card transition outcomes.

#### Scenario: Gesture smoke validation passes
- **WHEN** release candidate is executed on emulator or device
- **THEN** right-to-left, left-to-right, bottom-to-top, and top-to-bottom swipes each trigger the expected learning intent without runtime crash
