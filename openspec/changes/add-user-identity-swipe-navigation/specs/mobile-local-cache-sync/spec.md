## ADDED Requirements

### Requirement: Mobile stores optional user session locally
The mobile app SHALL persist active user session metadata separately from the stable device identifier.

#### Scenario: Session is saved after sign-in
- **WHEN** sign-in succeeds
- **THEN** the app stores the user session needed for future signed-in requests

#### Scenario: Device identifier remains after sign-out
- **WHEN** sign-out clears the active user session
- **THEN** the stable device identifier remains available for anonymous learning

### Requirement: Sync includes user identity when signed in
The mobile app SHALL include user identity on study-event and proficiency sync requests when a user session is active.

#### Scenario: Signed-in event is synced
- **WHEN** a pending study event is uploaded while a user session is active
- **THEN** the request includes both device_id and user identity

#### Scenario: Anonymous event is synced
- **WHEN** a pending study event is uploaded while no user session is active
- **THEN** the request includes device_id and omits user identity

### Requirement: Sign-in does not block offline learning
The mobile app SHALL allow learning to continue when sign-in, sign-out, or user sync is unavailable.

#### Scenario: Sign-in fails
- **WHEN** the sign-in request fails or times out
- **THEN** the app remains in anonymous mode and allows the learner to continue studying

#### Scenario: Signed-in sync fails
- **WHEN** a signed-in study event upload fails
- **THEN** the app keeps the event pending and retries without blocking the learning session
