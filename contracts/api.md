# API Contracts

## App Credential Headers

All `/v1/*` requests MUST include app credential headers. `GET /health` does
not require these headers.

```http
X-Expat8-App-Id: app_mobile_prod
X-Expat8-Timestamp: 2026-05-04T10:30:00.000Z
X-Expat8-Nonce: random-128-bit-or-larger
X-Expat8-Content-SHA256: base64url(sha256(raw_request_body))
X-Expat8-Signature: v1=base64url(hmac_sha256(secret, canonical_request))
```

Canonical request:

```text
v1
METHOD
PATH_WITH_SORTED_QUERY
TIMESTAMP
NONCE
CONTENT_SHA256
```

Invalid, missing, expired, replayed, or incorrectly signed app credential
requests return:

```json
{ "error": "bad_request" }
```

## Browser CORS

Browser preflight requests are the only `/v1/*` exception to app credential
headers. The backend answers `OPTIONS /v1/*` before raw-body capture and app
credential verification so web clients can send signed requests with custom
`x-expat8-*` headers.

Example preflight:

```http
OPTIONS /v1/users/register
Origin: http://localhost:8080
Access-Control-Request-Method: POST
Access-Control-Request-Headers: content-type,authorization,x-expat8-app-id,x-expat8-timestamp,x-expat8-nonce,x-expat8-content-sha256,x-expat8-signature
```

Expected response:

```http
204 No Content
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS
Access-Control-Allow-Headers: content-type, authorization, x-expat8-app-id, x-expat8-timestamp, x-expat8-nonce, x-expat8-content-sha256, x-expat8-signature
Access-Control-Max-Age: 86400
```

`Access-Control-Allow-Origin` uses `CORS_ALLOWED_ORIGIN`, defaulting to `*` for
development. Production deployments should set the exact web origin. Successful
`/v1/*` responses and expected API errors include the same CORS headers so
browser clients can read the response body. Non-OPTIONS `/v1/*` requests remain
protected by app credentials and return `400 { "error": "bad_request" }` when
unsigned or incorrectly signed.

## Optional User Session

App credentials are required for every `/v1/*` request. User identity is
optional and is layered inside that app credential check.

Signed-in requests include:

```http
Authorization: Bearer session_abc123
```

Learning endpoints continue to accept anonymous requests with `device_id`. When
a valid bearer session is present, the backend associates study events,
proficiency, and learned-word filtering with the user while still preserving the
request `device_id` for device/offline context. Invalid bearer sessions return:

```json
{ "error": "invalid_session" }
```

## POST /v1/users/register

Request:

```json
{
  "identifier": "learner@example.com",
  "password": "correct-password",
  "display_name": "Learner",
  "device_id": "device_abc"
}
```

Response `201`:

```json
{
  "user_id": "user_123",
  "identifier": "learner@example.com",
  "display_name": "Learner",
  "session_token": "session_abc123"
}
```

Duplicate identifiers return `409 { "error": "user_exists" }`. Invalid input
returns `400 { "error": "bad_request" }`.

## POST /v1/users/sign-in

Request:

```json
{
  "identifier": "learner@example.com",
  "password": "correct-password",
  "device_id": "device_abc"
}
```

Response `200`:

```json
{
  "user_id": "user_123",
  "identifier": "learner@example.com",
  "display_name": "Learner",
  "session_token": "session_def456"
}
```

Bad credentials return `401 { "error": "invalid_credentials" }`.

## POST /v1/users/sign-out

Requires a valid bearer session.

Response:

```json
{ "success": true }
```

## Vocabulary Item

```json
{
  "server_word_id": "word_123",
  "term": "reliable",
  "language": "en",
  "meaning_vi": "dang tin cay",
  "part_of_speech": "adjective",
  "ipa": "/rɪˈlaɪəbl/",
  "vietnamese_pronunciation": "ri-lai-uh-bol",
  "example": "She is a reliable teammate.",
  "example_vi": "Co ay la mot dong doi dang tin cay.",
  "difficulty": "B1",
  "topics": ["work", "people"],
  "created_at": "2026-05-04T00:00:00.000Z"
}
```

## GET /v1/words/next

Query parameters:

- `mode`: `new`
- `limit`: max items to return
- `source_language`: source language code, default `vi`
- `target_language`: target language code, default `en`
- `proficiency_level`: optional CEFR level filter: `A1`, `A2`, `B1`, `B2`, `C1`, `C2`
- `device_id`: optional device identifier; when present and `proficiency_level` is omitted, backend resolves current proficiency for that device
- `exclude_server_word_id`: optional repeated query parameter used to avoid already seen server word ids

Response:

```json
{
  "items": []
}
```

Notes:

- If no words exist at the exact requested proficiency level, the backend falls back to adjacent levels.
- Returned word `difficulty` values are canonical CEFR values.
- With a valid bearer session, the feed avoids words already learned by that
  user when alternatives are available.
- This compatibility endpoint is database-only. It never calls AI generation
  during the mobile request path.

## GET /v1/learning/cards

Backend-selected batch endpoint for the mobile refill path. This endpoint reads
only from database state and returns a target mix of 15% new cards and 85%
review cards, with shortage fallback when either pool is unavailable.

Query parameters:

- `device_id`: required device identifier.
- `limit`: maximum returned cards, capped at `50`.
- `target_language`: optional target language code, default `en`.

Response:

```json
{
  "target_mix": {
    "new": 3,
    "review": 17
  },
  "actual_mix": {
    "new": 3,
    "review": 17
  },
  "items": [
    {
      "server_word_id": "word_123",
      "term": "reliable",
      "language": "en",
      "meaning_vi": "dang tin cay",
      "part_of_speech": "adjective",
      "ipa": "/rɪˈlaɪəbl/",
      "vietnamese_pronunciation": "ri-lai-uh-bol",
      "example": "She is a reliable teammate.",
      "example_vi": "Co ay la mot dong doi dang tin cay.",
      "difficulty": "B1",
      "topics": ["work", "people"],
      "created_at": "2026-05-04T00:00:00.000Z",
      "card_type": "new",
      "selection_reason": "new_available"
    }
  ]
}
```

`card_type` is either `new` or `review`. `selection_reason` is diagnostic
metadata such as `new_available`, `due_review`,
`review_shortage_fallback`, or `new_shortage_fallback`.

With a valid bearer session, selection uses the signed-in `user_id` and keeps
`device_id` as device/cache context. Without a bearer session, selection uses
the anonymous `device_id`.

## GET /v1/words/recent

Query parameters:

- `limit`: maximum returned words, capped at `1000`
- `source_language`: source language code
- `target_language`: target language code

Response:

```json
{
  "items": []
}
```

## PUT /v1/user-word-cache

Replaces the backend's advisory inventory of server words currently stored on a
device. The inventory is used only to avoid duplicate card selection; it is not
authorization and is not proof that a word was studied.

Request:

```json
{
  "device_id": "device_abc",
  "server_word_ids": ["word_123", "word_456"],
  "observed_at": "2026-05-05T10:00:00.000Z"
}
```

Response:

```json
{
  "stored_count": 2,
  "unknown_server_word_ids": []
}
```

The backend caps stored IDs at `1000` and reports unknown IDs instead of
storing them. Signed-in requests associate the inventory with `user_id` while
retaining `device_id`.

Signed-in sync uses the same JSON body and adds `Authorization: Bearer
<session_token>`. Accepted events are associated with the user while retaining
the submitted `device_id`.

## POST /v1/study-events/sync

Request:

```json
{
  "device_id": "device_abc",
  "events": [
    {
      "client_event_id": "evt_001",
      "server_word_id": "word_123",
      "local_word_id": "local_456",
      "rating": "easy",
      "occurred_at": "2026-05-04T10:30:00.000Z"
    }
  ]
}
```

When signed in, include `Authorization: Bearer <session_token>`; the backend
stores the event under the user and keeps the submitted `device_id`.

Response:

```json
{
  "accepted_event_ids": ["evt_001"],
  "rejected_events": [],
  "proficiency": {
    "level": "A1",
    "level_changed": false,
    "previous_level": null,
    "triggered_by": null,
    "consecutive_count": 1,
    "consecutive_rating_type": "easy",
    "language": "en",
    "last_updated": "2026-05-04T10:30:00.000Z"
  }
}
```

Valid rating values:

- `easy`
- `too_easy`
- `hard`
- `too_hard`

## POST /v1/study-events

Request:

```json
{
  "device_id": "device_abc",
  "client_event_id": "evt_002",
  "word_id": "word_123",
  "server_word_id": "word_123",
  "local_word_id": "local_456",
  "rating": "too_easy",
  "occurred_at": "2026-05-04T10:31:00.000Z",
  "language": "en"
}
```

Response:

```json
{
  "success": true,
  "event_id": "study_event_123",
  "idempotent": false,
  "proficiency": {
    "level": "A2",
    "level_changed": true,
    "previous_level": "A1",
    "triggered_by": "5x consecutive too_easy",
    "consecutive_count": 0,
    "consecutive_rating_type": null,
    "language": "en",
    "last_updated": "2026-05-04T10:31:00.000Z"
  }
}
```

## GET /v1/proficiency

Query parameters:

- `device_id`: required device identifier
- `language`: optional language code, default `en`

Response:

```json
{
  "device_id": "device_abc",
  "user_id": null,
  "level": "A1",
  "level_changed": false,
  "previous_level": null,
  "triggered_by": null,
  "consecutive_count": 0,
  "consecutive_rating_type": null,
  "language": "en",
  "last_updated": "2026-05-04T10:30:00.000Z"
}
```

With a valid bearer session, `user_id` is populated and the level reflects the
signed-in user's proficiency state instead of anonymous device state.
