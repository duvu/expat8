## Purpose
Define that the exam start endpoint accepts a language-only request body without requiring a topic field.

## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Exam start requires topic field
**Reason**: Language-scoped exam sessions no longer need a topic; the store selects all studied words for the language.
**Migration**: Remove `topic` from any `POST /v1/exam/start` request bodies. The field is silently ignored if present.
