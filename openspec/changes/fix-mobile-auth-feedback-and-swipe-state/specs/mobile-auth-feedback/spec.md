## ADDED Requirements

### Requirement: Auth actions provide visible feedback
The mobile app SHALL provide visible user feedback for register, sign-in, and sign-out actions.

#### Scenario: Registration succeeds
- **WHEN** a learner submits valid registration details and the backend returns a user session
- **THEN** the app stores the session and displays a visible registration success message

#### Scenario: Registration fails
- **WHEN** registration fails because of invalid input, duplicate identifier, app credential failure, timeout, TLS failure, or network unavailability
- **THEN** the app remains in anonymous mode and displays a visible error message

#### Scenario: Sign-in succeeds
- **WHEN** a learner submits valid sign-in credentials and the backend returns a user session
- **THEN** the app stores the session and displays a visible sign-in success message

#### Scenario: Sign-in fails
- **WHEN** sign-in fails because of invalid credentials, backend rejection, timeout, TLS failure, or network unavailability
- **THEN** the app keeps the previous session state and displays a visible error message

#### Scenario: Sign-out completes
- **WHEN** a signed-in learner signs out
- **THEN** the app clears the active session and displays a visible sign-out confirmation

### Requirement: Auth actions expose loading state
The mobile app SHALL prevent ambiguous duplicate auth submissions while register, sign-in, or sign-out is in progress.

#### Scenario: Registration is in progress
- **WHEN** registration is awaiting backend response
- **THEN** the app shows an auth loading state and disables duplicate register submissions

#### Scenario: Sign-in is in progress
- **WHEN** sign-in is awaiting backend response
- **THEN** the app shows an auth loading state and disables duplicate sign-in submissions

### Requirement: Active user info is visible
The mobile app SHALL display active signed-in user information when a user session is available.

#### Scenario: Signed-in session has display name
- **WHEN** a user session is active and contains `displayName`
- **THEN** the drawer or app chrome displays the display name

#### Scenario: Signed-in session has no display name
- **WHEN** a user session is active and does not contain `displayName`
- **THEN** the drawer or app chrome displays the session identifier

#### Scenario: App loads stored session
- **WHEN** the app starts and a stored user session exists
- **THEN** the app displays the signed-in user information without requiring another sign-in

### Requirement: Anonymous learning remains available after auth failure
The mobile app SHALL keep vocabulary learning available when auth actions fail.

#### Scenario: Register fails while learning is available
- **WHEN** registration fails
- **THEN** the learner can continue using device-based vocabulary learning

#### Scenario: Sign-in fails while learning is available
- **WHEN** sign-in fails
- **THEN** the learner can continue using device-based vocabulary learning
