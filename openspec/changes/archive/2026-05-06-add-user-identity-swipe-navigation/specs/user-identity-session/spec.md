## ADDED Requirements

### Requirement: User can register an account
The system SHALL allow an anonymous learner to register a user account before signing in for server-side identity tracking.

#### Scenario: Learner registers successfully
- **WHEN** an anonymous learner submits valid registration details
- **THEN** the backend creates a user account and returns a user session the app can store

#### Scenario: Registration identifier already exists
- **WHEN** a learner submits registration details with an identifier already used by another account
- **THEN** the backend rejects registration without creating a duplicate user account

#### Scenario: Registration fails
- **WHEN** registration fails because details are invalid or the network is unavailable
- **THEN** the app remains in anonymous mode and allows the learner to continue studying

### Requirement: User sign-in is optional
The system SHALL allow learners to use the app without signing in and SHALL allow learners to sign in when they want server-side identity tracking.

#### Scenario: Learner continues anonymously
- **WHEN** a learner opens the app and does not sign in
- **THEN** the app continues using device-based local learning and sync behavior

#### Scenario: Learner signs in
- **WHEN** a learner completes the sign-in flow
- **THEN** the app stores an active user session and includes user identity on eligible backend learning requests

#### Scenario: Learner signs in after registration
- **WHEN** a learner has just registered successfully
- **THEN** the app treats the returned session as an active signed-in user session

### Requirement: User can sign out
The system SHALL allow a signed-in learner to sign out without deleting the local device identifier or local vocabulary cache.

#### Scenario: Signed-in learner signs out
- **WHEN** the learner chooses Sign out
- **THEN** the app clears the active user session and returns to anonymous device-based learning

#### Scenario: Local cache survives sign out
- **WHEN** sign-out completes
- **THEN** previously cached vocabulary and pending anonymous-capable local study state remain available on the device

### Requirement: Signed-in learning data is associated with the user
The backend SHALL associate signed-in study events, learned-word state, and proficiency state with the authenticated user while preserving the device identifier.

#### Scenario: Signed-in study event is submitted
- **WHEN** the backend receives a valid study event request with user identity and device_id
- **THEN** the backend stores the event with the user and device association

#### Scenario: Signed-in proficiency is requested
- **WHEN** the app requests proficiency while signed in
- **THEN** the backend returns the user's proficiency state instead of only the device-based state

### Requirement: User session is independent from app credential security
The backend SHALL require app credential verification for public API requests and SHALL process user session identity as a separate inner authorization layer.

#### Scenario: Signed-in request is missing app credentials
- **WHEN** a request includes user session data but is missing valid app credential headers
- **THEN** the backend rejects the request before user session handling

#### Scenario: Anonymous request has valid app credentials
- **WHEN** an anonymous request includes valid app credentials and a device_id
- **THEN** the backend may process it through the anonymous device-based path
