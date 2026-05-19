## ADDED Requirements

### Requirement: Backend issues a certificate when the passing threshold is met
The system SHALL automatically create an `exam_certificates` record when an exam attempt is persisted with `passed = true`. The certificate SHALL contain: certificate_id (UUID), user_id, topic, language, difficulty_level, score_pct, issued_at.

#### Scenario: Certificate created on passing submission
- **WHEN** `POST /v1/exam/submit` completes with score_pct ≥ 70%
- **THEN** a row is inserted into `exam_certificates` and the response includes the `certificate_id`

#### Scenario: No certificate created on failing submission
- **WHEN** `POST /v1/exam/submit` completes with score_pct < 70%
- **THEN** no `exam_certificates` row is created and the response `certificate_id` field is null

### Requirement: Certificate is retrievable by ID without authentication
The system SHALL expose `GET /v1/exam/certificate/:id` as a public endpoint (no app-credential headers required) so that certificates can be shared and verified by anyone with the link.

#### Scenario: Valid certificate ID
- **WHEN** `GET /v1/exam/certificate/:id` is called with a valid UUID
- **THEN** the backend returns the certificate JSON: certificate_id, topic, language, difficulty_level, score_pct, issued_at (user PII such as user_id is NOT included in the public response)

#### Scenario: Certificate ID not found
- **WHEN** `GET /v1/exam/certificate/:id` is called with an unknown UUID
- **THEN** the backend returns HTTP 404

### Requirement: Certificate does not imply external qualification equivalence
The certificate response SHALL include a `disclaimer` field stating that it is an internal Expat8 completion certificate and does not represent an official CEFR or HSK examination result.

#### Scenario: Disclaimer is present in certificate response
- **WHEN** `GET /v1/exam/certificate/:id` returns a valid certificate
- **THEN** the JSON includes a non-empty `disclaimer` string

### Requirement: Mobile displays and allows sharing of the certificate
The system SHALL render a certificate view screen on mobile showing the topic, language, level, score, issued date, and a share button that invokes the platform share sheet with the certificate URL.

#### Scenario: User views certificate from results screen
- **WHEN** the user taps "View Certificate" on the results screen after passing
- **THEN** the app navigates to the certificate screen displaying all certificate fields

#### Scenario: User shares certificate
- **WHEN** the user taps "Share" on the certificate screen
- **THEN** the platform share sheet opens with the certificate URL (`/v1/exam/certificate/:id` on the configured BACKEND_BASE_URL)
