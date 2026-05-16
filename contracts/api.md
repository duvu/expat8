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

## GET /health/ready

Readiness probe. No app credential headers required.

Response `200`:

```json
{ "ok": true, "db": "ok" }
```

Response `503`:

```json
{ "ok": false, "db": "error" }
```

## GET /v1/me

Requires a valid bearer session.

Response:

```json
{
  "user_id": "user_123",
  "identifier": "learner@example.com",
  "display_name": "Learner"
}
```

## GET /v1/articles/:id/vocabulary

Returns vocabulary extracted from a user-owned article or a published article.

Response:

```json
{
  "article_id": "article_123",
  "items": [
    {
      "term_id": "term_123",
      "display_term": "reliable",
      "word_sense_id": "sense_123",
      "meaning_vi": "dang tin cay",
      "part_of_speech": "adjective",
      "ipa": "/rɪˈlaɪəbl/",
      "level": "A1",
      "status": "approved",
      "classification": "article_keyword",
      "suggestion_type": "word"
    }
  ]
}
```

## DELETE /v1/articles/:id

Soft-deletes a user-owned article.

Response:

```json
{ "success": true }
```

## PATCH /v1/admin/articles/:id

Admin-only metadata patch. Allowed fields: `title`, `language`, `visibility`, `status`. Valid `visibility` values are `'private'` and `'published'`; `'shared'` is not accepted and returns `400`.

Response:

```json
{
  "id": "article_123",
  "title": "Updated title"
}
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
  "entry_type": "word",
  "explanation": "",
  "speaking_prompt": {
    "id": "prompt_123",
    "target_text": "She is a reliable teammate.",
    "vi_hint": "Co ay la mot dong doi dang tin cay.",
    "target_phrase": "reliable teammate",
    "pronunciation_tip_vi": "Tap trung noi ro am cuoi /l/ trong reliable.",
    "common_mistake_vi": "Nguoi Viet de bo am cuoi hoac nhan sai trong am.",
    "difficulty": "B1",
    "topic": "work"
  },
  "difficulty": "B1",
  "topics": ["work", "people"],
  "created_at": "2026-05-04T00:00:00.000Z"
}
```

`speaking_prompt` is optional. When present, it contains an approved prompt for
local speaking practice. Mobile clients MUST treat it as practice text only; no
audio recording is uploaded as part of card loading or study-event sync.

`entry_type` is one of `"word"`, `"phrase"`, or `"idiom"`. For `phrase` and
`idiom` entries, `ipa` and `part_of_speech` are empty strings. `explanation`
contains a Vietnamese usage note for the entry; it is an empty string for plain
words.

## POST /v1/learning/cards

Backend-selected batch endpoint for the mobile card-loading path. This is the
only supported API for loading learning cards. `GET /v1/words/next` has been
removed and is not kept as a compatibility route.

The request MUST NOT include client-side word exclusions such as current word
IDs, `exclude_server_word_id`, or any other exclusion list. Duplicate avoidance
is owned by backend learner state and active cache/claim inventory.

Request:

```json
{
  "device_id": "anonymous_550e8400-e29b-41d4-a716-446655440000",
  "target_language": "en",
  "limit": 10,
  "card_mode": "new"
}
```

Fields:

- `device_id`: required stable anonymous or device identifier. Anonymous mobile
  clients use `anonymous_<uuid-v4>`.
- `target_language`: optional target language code, default `en`.
- `limit`: optional maximum returned cards, capped at `100`.
- `card_mode`: optional mode. `new` is the only supported value for this flow.
  Missing, `null`, or empty values are treated as `new`. Any other value
  returns `400 { "error": "bad_request" }`.

Response:

```json
{
  "target_mix": {
    "new": 10,
    "review": 0
  },
  "actual_mix": {
    "new": 10,
    "review": 0
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
      "speaking_prompt": {
        "id": "prompt_123",
        "target_text": "She is a reliable teammate.",
        "vi_hint": "Co ay la mot dong doi dang tin cay.",
        "target_phrase": "reliable teammate",
        "pronunciation_tip_vi": "Tap trung noi ro am cuoi /l/ trong reliable.",
        "common_mistake_vi": "Nguoi Viet de bo am cuoi hoac nhan sai trong am.",
        "difficulty": "B1",
        "topic": "work"
      },
      "difficulty": "B1",
      "topics": ["work", "people"],
      "created_at": "2026-05-04T00:00:00.000Z",
      "card_type": "new",
      "selection_reason": "new_available"
    }
  ]
}
```

`card_type` is `new` for this flow. `selection_reason` is diagnostic metadata
such as `new_available`.

With a valid bearer session, selection uses the signed-in `user_id` and keeps
`device_id` as device/cache context. Signed-in selection also excludes anonymous
history and active cache claims for the submitted device. Without a bearer
session, selection uses the anonymous `device_id`. Returned word IDs are
persisted as active cache/claim inventory before the response is completed.

## GET /v1/words/recent

Query parameters:

- `limit`: maximum returned words, capped at `1000`
- `target_language`: optional target language code, default `en`

This endpoint is read-only bootstrap/diagnostic support. It does not accept
`device_id`, source-language, current-word, or exclusion-list parameters.
Learner-specific duplicate avoidance belongs to `POST /v1/learning/cards` and
`PUT /v1/user-word-cache`.

Response:

```json
{
  "items": []
}
```

## GET /v1/workplace-sentences/recent

Query parameters:

- `limit`: maximum returned sentence items, capped at `1000`
- `target_language`: optional target language code, default `en`

This endpoint returns prepared workplace sentence items for local bootstrap and
background refill. It is read-only and MUST NOT trigger sentence generation in
the request path.

Response:

```json
{
  "items": [
    {
      "sentence_id": "sentence_123",
      "text": "Could we move this meeting to tomorrow morning?",
      "language": "en",
      "meaning_vi": "Chung ta co the chuyen cuoc hop nay sang sang mai duoc khong?",
      "topic": "meetings",
      "source_article_id": "article_123",
      "source_title": "How teams coordinate deadlines",
      "generation_source": "article_workplace_sentence",
      "created_at": "2026-05-16T00:00:00.000Z"
    }
  ]
}
```

Only sentences from published source articles are eligible for this feed.

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

The sync endpoint also accepts non-rating speaking events in the same `events`
array. Speaking events MUST include `event_type` and `speaking` metadata, MUST
NOT include raw audio bytes, and MUST NOT include local audio file paths.

Supported speaking event types:

- `speaking_prompt_viewed`
- `speaking_sample_played`
- `speaking_recorded`
- `speaking_retried`
- `speaking_self_rated_clear`
- `speaking_self_rated_hesitated`
- `speaking_self_rated_could_not_say`
- `speaking_drill_completed`

Speaking event example:

```json
{
  "device_id": "device_abc",
  "events": [
    {
      "client_event_id": "evt_speak_001",
      "event_type": "speaking_recorded",
      "occurred_at": "2026-05-04T10:32:00.000Z",
      "language": "en",
      "speaking": {
        "attempt_id": "attempt_001",
        "prompt_id": "prompt_123",
        "word_sense_id": "sense_123",
        "server_word_id": "word_123",
        "duration_ms": 4200,
        "retry_count": 0,
        "self_rating": null
      }
    },
    {
      "client_event_id": "evt_speak_002",
      "event_type": "speaking_self_rated_clear",
      "occurred_at": "2026-05-04T10:32:08.000Z",
      "language": "en",
      "speaking": {
        "attempt_id": "attempt_001",
        "prompt_id": "prompt_123",
        "word_sense_id": "sense_123",
        "duration_ms": 4200,
        "retry_count": 0,
        "self_rating": "clear"
      }
    }
  ]
}
```

Allowed `speaking.self_rating` values are `clear`, `hesitated`,
`could_not_say`, or `null` when the event is not a self-rating event. The backend
stores speaking events separately from rating study events, so speaking events do
not update memory scheduling or proficiency.

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

`POST /v1/study-events` remains a single rating-event endpoint and requires a
valid `rating`. Use `POST /v1/study-events/sync` for speaking events.

## GET /v1/speaking/summary

Returns a weekly local-speaking summary derived from accepted speaking events.
No learner audio is returned or stored by this endpoint.

Query parameters:

- `device_id`: required stable device identifier for anonymous learners.
- `language`: optional language code, default `en`.
- `week_start`: optional ISO date for the requested week. If omitted, the
  backend uses the current week.

When signed in, include `Authorization: Bearer <session_token>`; the backend
uses the user context while retaining `device_id` for offline/device continuity.

Response:

```json
{
  "device_id": "device_abc",
  "user_id": "user_123",
  "language": "en",
  "week_start": "2026-05-04",
  "spoken_sentence_count": 12,
  "recording_count": 12,
  "retry_count": 3,
  "retry_rate": 0.25,
  "drill_sessions_completed": 2,
  "approximate_duration_ms": 52200,
  "self_rating_counts": {
    "clear": 7,
    "hesitated": 4,
    "could_not_say": 1
  },
  "first_recording_at": "2026-05-01T09:00:00.000Z",
  "latest_activity_at": "2026-05-09T08:15:00.000Z"
}
```

`retry_rate` is `retry_count / recording_count` (0 when no recordings).
`drill_sessions_completed` counts `speaking_drill_completed` events in the
requested week. `first_recording_at` is the ISO timestamp of the earliest
`speaking_recorded` event for the device across all time, or `null`.

Missing `device_id` returns `400 { "error": "bad_request" }`.

## GET /v1/speaking/prompts

Returns approved speaking prompts for mobile offline drill sync.

Query parameters:

- `limit`: optional maximum returned prompts, capped at `200`, default `100`.
- `word_sense_id`: optional filter to prompts for a specific word sense.

Response:

```json
{
  "items": [
    {
      "id": "speaking_prompt_123",
      "target_text": "She is a reliable teammate.",
      "vi_hint": "Co ay la mot dong doi dang tin cay.",
      "target_phrase": "reliable teammate",
      "pronunciation_tip_vi": "Tap trung noi ro am cuoi /l/ trong reliable.",
      "common_mistake_vi": "Nguoi Viet de bo am cuoi hoac nhan sai trong am.",
      "difficulty": "B1",
      "topic": "work"
    }
  ]
}
```

## GET /v1/admin/speaking-prompts

Admin-only. Lists speaking prompts with optional filters.

Query parameters:

- `status`: optional filter — `pending_review`, `approved`, or `rejected`.
- `missing_required`: `true` to return only prompts missing `target_text` or `vi_hint`.
- `limit`: optional maximum returned, capped at `200`, default `100`.

Requires app credentials and admin token (`X-Expat8-Admin-Token`).
Missing app credentials return `400`. Valid app credentials without admin token return `403`.

Response:

```json
{
  "items": [
    {
      "id": "speaking_prompt_123",
      "word_sense_id": "sense_123",
      "target_text": "She is a reliable teammate.",
      "vi_hint": "Co ay la mot dong doi dang tin cay.",
      "target_phrase": "reliable teammate",
      "pronunciation_tip_vi": "...",
      "common_mistake_vi": "...",
      "difficulty": "B1",
      "topic": "work",
      "status": "pending_review",
      "created_at": "2026-05-04T00:00:00.000Z",
      "updated_at": "2026-05-04T00:00:00.000Z"
    }
  ]
}
```

## PATCH /v1/admin/speaking-prompts/:id

Admin-only. Updates speaking prompt fields.

Patchable fields: `target_text`, `vi_hint`, `target_phrase`, `pronunciation_tip_vi`,
`common_mistake_vi`, `difficulty`, `topic`, `status`.

Valid `status` values: `pending_review`, `approved`, `rejected`.
Invalid status returns `400 { "error": "bad_request", "message": "invalid_status" }`.
Unknown prompt ID returns `404 { "error": "not_found" }`.

Response:

```json
{
  "id": "speaking_prompt_123",
  "status": "approved",
  "target_text": "She is a reliable teammate.",
  "updated_at": "2026-05-09T10:00:00.000Z"
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

---

## Exam Endpoints

All exam endpoints (except `GET /v1/exam/certificate/:id`) require the standard
app-credential headers **and** a valid bearer session token.

`GET /v1/exam/certificate/:id` is public — no auth headers required.

### GET /v1/exam/topics

Returns the distinct topics the authenticated user has studied words in for the
given language. Topics are normalised (lowercase, trimmed). This endpoint is
retained for historical browsing, but the primary exam flow no longer depends
on topic selection.

Query parameters:

- `language`: optional, default `en`

Response:

```json
{ "topics": ["business", "food", "travel"] }
```

---

### POST /v1/exam/start

Generates a new exam session with MCQ questions drawn from the user's studied
words for the requested language. Minimum 5 words required; capped at 20
questions.

Request body:

```json
{
  "language": "en"
}
```

Success response (201):

```json
{
  "session_id": "exam_sess_<uuid>",
  "topic": "language",
  "language": "en",
  "question_count": 10,
  "expires_at": "2026-05-11T14:00:00.000Z",
  "questions": [
    {
      "question_id": "exam_q_<uuid>",
      "ordinal": 0,
      "prompt_word": "journey",
      "choices": ["chuyến đi", "bữa ăn", "công việc", "gia đình"],
      "question_type": "meaning_choice"
    },
    {
      "question_id": "exam_q_<uuid>",
      "ordinal": 1,
      "prompt_word": "break the ice",
      "choices": ["phá vỡ bầu không khí ngại ngùng", "bắt đầu công việc", "tiết lộ bí mật", "cảm thấy mệt mỏi"],
      "question_type": "sentence_context",
      "sentence": "He told a joke to break the ice at the meeting.",
      "highlight": "break the ice"
    }
  ]
}
```

Each question object always contains `question_type` (`"meaning_choice"` or
`"sentence_context"`). For `sentence_context` questions, `sentence` (the example
sentence) and `highlight` (the term to emphasize) are also present. Questions
with an empty `example` always receive `"meaning_choice"`; questions with a
non-empty `example` are randomly assigned either type (50/50).

Error responses:

| Status | `error` field        | Meaning                                      |
|--------|----------------------|----------------------------------------------|
| 400    | `bad_request`        | `topic` missing from body                    |
| 401    | `invalid_session`    | Missing or invalid bearer token              |
| 422    | `INSUFFICIENT_WORDS` | Fewer than 5 studied words exist for language |

```json
{
  "error": "INSUFFICIENT_WORDS",
  "message": "Not enough studied words for language \"en\". Found 3, need at least 5."
}
```

---

### POST /v1/exam/submit

Submits answers for an active session and scores it. A passing score (≥ 70%)
triggers certificate issuance.

Request body:

```json
{
  "session_id": "exam_sess_<uuid>",
  "answers": [2, 0, 1, 3]
}
```

`answers` is an array of integer choice indices (0-based) in question ordinal
order. Its length must equal `question_count` from `POST /v1/exam/start`.

Success response (200):

```json
{
  "attempt_id": "exam_att_<uuid>",
  "session_id": "exam_sess_<uuid>",
  "topic": "travel",
  "language": "en",
  "difficulty_level": null,
  "total_questions": 10,
  "correct_count": 8,
  "score_pct": 80,
  "passed": true,
  "certificate_id": "<uuid>",
  "created_at": "2026-05-11T12:01:00.000Z"
}
```

`certificate_id` is `null` when `passed` is `false`.

Error responses:

| Status | `error` field          | Meaning                                    |
|--------|------------------------|--------------------------------------------|
| 400    | `bad_request`          | Missing `session_id` or `answers`          |
| 401    | `invalid_session`      | Missing or invalid bearer token            |
| 404    | `not_found`            | Session ID not found                       |
| 409    | `ALREADY_SUBMITTED`    | Session was already submitted              |
| 410    | `SESSION_EXPIRED`      | Session TTL (2 hours) exceeded             |
| 422    | `ANSWER_COUNT_MISMATCH`| `answers.length` ≠ `question_count`        |

---

### GET /v1/exam/results

Returns the authenticated user's exam attempt history, newest first.

Query parameters:

- `page`: optional, default `1`
- `limit`: optional, default `20`, max `100`

Response:

```json
{
  "items": [
    {
      "attempt_id": "exam_att_<uuid>",
      "topic": "travel",
      "language": "en",
      "difficulty_level": null,
      "score_pct": 80,
      "passed": true,
      "created_at": "2026-05-11T12:01:00.000Z",
      "certificate_id": "<uuid>"
    }
  ],
  "total": 1,
  "page": 1,
  "limit": 20
}
```

`certificate_id` is `null` when the attempt did not pass.

---

### GET /v1/exam/certificate/:id

**Public endpoint** — no app-credential or session headers required.

Returns a certificate record without user PII.

Success response (200):

```json
{
  "certificate_id": "<uuid>",
  "topic": "travel",
  "language": "en",
  "difficulty_level": null,
  "score_pct": 80,
  "issued_at": "2026-05-11T12:01:00.000Z",
  "disclaimer": "This is an internal Expat8 completion certificate. It does not represent an official CEFR or HSK examination result."
}
```

Error responses:

| Status | `error` field | Meaning                    |
|--------|---------------|----------------------------|
| 404    | `not_found`   | Certificate ID not found   |
