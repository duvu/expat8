## Purpose
Define the navigation contract for the mobile exam flow so the Done action on results returns to the learning screen.

## Requirements

### Requirement: Results Done returns to learning screen
The mobile app SHALL return to the learning screen when the user taps `Done` on the exam results screen, without removing the learning screen route or leaving the app on a blank screen.

#### Scenario: Done tapped after exam results
- **WHEN** the user completes an exam, reaches the results screen, and taps `Done`
- **THEN** the app returns to the learning screen and the navigator retains a visible route

#### Scenario: Done resets exam state
- **WHEN** the user taps `Done` on the exam results screen
- **THEN** the exam session controller MUST be reset before the results route is dismissed

### Requirement: Results navigation matches language-only exam flow
The mobile exam results navigation SHALL assume the current direct exam flow, where the question route is replaced by the results route and no topic-picker route exists beneath results.

#### Scenario: No topic route is present
- **WHEN** the exam results screen is shown after the final answer
- **THEN** results actions MUST NOT require a topic-picker route to exist in the navigator stack
