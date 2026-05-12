# exam-start-validation Specification

## Purpose
TBD - created by archiving change fix-exam-start-error. Update Purpose after archive.
## Requirements
### Requirement: Exam start accepts language-only request body
The backend `POST /v1/exam/start` endpoint SHALL accept a request body containing only a `language` field (no `topic` field required).

#### Scenario: Successful exam start with language only
- **WHEN** a signed mobile client sends `POST /v1/exam/start` with body `{"language": "en"}`
- **THEN** the server SHALL respond with HTTP 201 and a valid exam session payload

#### Scenario: Missing language defaults to en
- **WHEN** a client sends `POST /v1/exam/start` with an empty body
- **THEN** the server SHALL default `language` to `"en"` and proceed normally

#### Scenario: Topic field is silently ignored
- **WHEN** a client sends `POST /v1/exam/start` with body `{"language": "en", "topic": "anything"}`
- **THEN** the server SHALL ignore `topic` and proceed as if only `language` was provided

#### Scenario: Insufficient words returns 422 with language in message
- **WHEN** a client sends `POST /v1/exam/start` and the user has fewer than 5 studied words for the given language
- **THEN** the server SHALL respond with HTTP 422 and an error message referencing the `language`, not `topic`

