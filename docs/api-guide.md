# API Guide

The canonical API reference is [`contracts/api.md`](../contracts/api.md). This guide summarizes operational API rules and endpoint groups; when this guide and the contract disagree, the contract wins.

## Authentication and Signing

All non-OPTIONS `/v1/*` requests require app credential headers:

```http
X-Expat8-App-Id: app_mobile_prod
X-Expat8-Timestamp: 2026-05-04T10:30:00.000Z
X-Expat8-Nonce: random-128-bit-or-larger
X-Expat8-Content-SHA256: base64url(sha256(raw_request_body))
X-Expat8-Signature: v1=base64url(hmac_sha256(secret, canonical_request))
```

Canonical request format:

```text
v1
METHOD
PATH_WITH_SORTED_QUERY
TIMESTAMP
NONCE
CONTENT_SHA256
```

Invalid, missing, expired, replayed, or incorrectly signed app credential requests return `400 { "error": "bad_request" }`.

## Unsigned Exceptions

- `GET /health`.
- `GET /health/ready`.
- `OPTIONS /v1/*` CORS preflight.
- `GET /v1/exam/certificate/:id` public certificate reads.

## Optional User Session

Signed-in requests include:

```http
Authorization: Bearer <session_token>
```

User sessions are optional for supported learning flows. A valid bearer token associates study events, proficiency, learned-word filtering, and account data with the user while preserving `device_id` for offline/device context. Invalid bearer sessions return an `invalid_session` error.

## Admin Requests

Admin endpoints under `/v1/admin/*` still require app credentials. They additionally require an admin token configured by `ADMIN_API_TOKENS`; missing or invalid admin auth returns forbidden behavior per the contract/handlers.

## Endpoint Groups

- Health/readiness: deployment and database readiness checks.
- Users/session: register, sign in, sign out, and current-user lookup.
- Learning cards: backend-selected card batches.
- Study events/sync: single and batched learner event submission.
- Proficiency: language-native learner level state.
- User word cache: mobile inventory reporting for duplicate avoidance.
- User-submitted words: learner-entered vocabulary enrichment lifecycle.
- Articles/vocabulary: content ingestion and vocabulary extraction results.
- Admin articles/vocabulary/logs/prompts: review and operations workflows.
- Speaking: prompt/event/summary APIs for the speaking foundation.
- Exam: start, answer, result, and public certificate endpoints.
- Mobile logs: raw text diagnostic archive upload.

## Learning Card Contract Invariants

- `POST /v1/learning/cards` must use `card_mode: "new"` or omit `card_mode`.
- `exclude_server_word_ids`, `current_word_id`, and other client-side exclusion fields are rejected.
- Duplicate avoidance is backend-owned and informed by `PUT /v1/user-word-cache`.

## Exam Contract Invariants

- `POST /v1/exam/start` requires at least five studied words.
- Exam sessions are capped at twenty questions.
- Sessions expire after two hours.
- Passing score is at least 70% and triggers certificate issuance.

## CORS

Browser preflight requests are answered before app credential verification. Non-OPTIONS `/v1/*` browser requests still need app credential signing. `CORS_ALLOWED_ORIGIN` defaults to `*` for development and should be set to an exact production origin.
