## ADDED Requirements

### Requirement: Auth dialogs validate input before network submission
The mobile app SHALL validate registration and sign-in dialog input locally before closing the dialog or sending a backend request.

#### Scenario: Identifier is empty
- **WHEN** the user submits the register or sign-in dialog with an empty identifier
- **THEN** the app keeps the dialog open and displays an identifier validation error without sending a backend request

#### Scenario: Identifier is malformed for the email UI
- **WHEN** the user submits the register or sign-in dialog with text that is not a valid email-like identifier
- **THEN** the app keeps the dialog open and displays an identifier validation error without sending a backend request

#### Scenario: Password is too short
- **WHEN** the user submits the register or sign-in dialog with a password shorter than the backend minimum
- **THEN** the app keeps the dialog open and displays a password validation error without sending a backend request

#### Scenario: Auth input is valid
- **WHEN** the user submits the register or sign-in dialog with valid identifier and password input
- **THEN** the app closes the dialog and starts the corresponding auth request

### Requirement: Auth actions expose visible in-progress feedback
The mobile app SHALL display visible progress feedback while register, sign-in, or sign-out requests are in flight.

#### Scenario: Register request is in progress
- **WHEN** the app is waiting for a register request to complete
- **THEN** the learning screen displays an auth progress indicator and prevents duplicate auth submission

#### Scenario: Sign-in request is in progress
- **WHEN** the app is waiting for a sign-in request to complete
- **THEN** the learning screen displays an auth progress indicator and prevents duplicate auth submission

#### Scenario: Sign-out request is in progress
- **WHEN** the app is waiting for a sign-out request to complete
- **THEN** the learning screen displays an auth progress indicator and prevents duplicate auth submission

#### Scenario: Auth request completes
- **WHEN** an auth request succeeds or fails
- **THEN** the app hides the auth progress indicator and shows the existing success or error feedback path
