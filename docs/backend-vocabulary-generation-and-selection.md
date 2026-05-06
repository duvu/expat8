# Backend Vocabulary Generation and Selection Design

> Historical note (2026-05-06): this design documents the transition away from
> AI generation in the mobile request path. Current card loading uses
> `POST /v1/learning/cards`; `/v1/words/next` references are retained only as
> historical design context.

## Purpose

Tài liệu này mô tả hướng cập nhật backend để tách riêng hai quá trình đang bị trộn lẫn:

1. Backend tự gọi AI để duy trì kho từ vựng.
2. Mobile app lấy thẻ học từ kho dữ liệu đã có.

Mục tiêu là khi mobile query từ mới hoặc thẻ học, backend chỉ đọc database và chọn thẻ phù hợp. Backend không gọi AI trong request path của mobile nữa.

## Current Shape

Hiện tại backend có các phần liên quan:

- `VocabularyGenerationService.generateAndStore()` gọi LiteLLM và insert từ vào `words`.
- `GET /v1/words/next` trước tiên đọc `store.findNewWords()`, nhưng nếu thiếu từ thì gọi AI on-demand qua `generationService.generateAndStore()`.
- `GET /v1/words/recent` trả tối đa 1000 từ gần nhất để mobile bootstrap.
- `study_events` lưu mỗi lần học/rating theo `client_event_id`.
- Mobile có `local_words`, `study_events`, `sync_queue`, `VocabularyRefreshWorker`, và local cache cap 1000 từ.

Điểm cần đổi: AI generation không nên xảy ra khi mobile đang chờ một thẻ học.

```text
Current request path

Mobile ── GET /v1/words/next ──▶ Backend
                                  │
                                  ├─ DB lookup
                                  │
                                  └─ if missing:
                                     call AI during request
                                     insert words
                                     return response

Desired request path

Backend scheduler ──▶ AI ──▶ words database

Mobile ── GET cards ──▶ Backend ──▶ DB selection only ──▶ Mobile
```

## Target Behavior

Implementation status: this design is implemented by the
`backend-managed-vocabulary-pool-selection` change. The current runtime uses a
database-only mobile request path, a background `VocabularyPoolScheduler`, a
batch card endpoint, cache inventory sync, append-only study events, and latest
word-state projection.

### Vocabulary pool maintenance

Backend owns a vocabulary pool per target language.

- Until the database has at least 1000 usable words for a language, backend tries to generate new words every minute.
- After the database reaches 1000 usable words, backend generates 10 new words per day.
- AI generation is asynchronous and independent from mobile requests.
- Generated words are validated and deduplicated by `(language, normalized_term)`.
- Failed AI calls do not break mobile requests; they are logged and retried by the next scheduler run.

Suggested defaults:

| Setting | Default | Meaning |
|---|---:|---|
| `VOCAB_POOL_MIN_SIZE` | `1000` | Minimum target word count per language |
| `VOCAB_FILL_INTERVAL_SECONDS` | `60` | Scheduler cadence while pool is below target |
| `VOCAB_DAILY_GENERATION_COUNT` | `10` | New words generated after pool is full |
| `VOCAB_DAILY_GENERATION_HOUR_UTC` | `0` | Hour used for daily top-up |
| `VOCAB_GENERATION_BATCH_SIZE` | `20` | Max words requested per AI call |
| `VOCAB_SCHEDULER_ENABLED` | `true` | Whether server startup starts the scheduler |
| `VOCAB_SCHEDULER_LOCK_TTL_SECONDS` | `120` | Lock expiration for concurrent backend instances |

### Mobile card selection

When mobile requests learning cards, backend chooses from database using user/device state.

Target ratio:

- 15% new words
- 85% review words

This ratio should be treated as a selection target over a batch or rolling window, not as a guarantee for every single request. For example, for a request of 20 cards:

```text
20 requested cards
├─ 3 new cards       (15%)
└─ 17 review cards   (85%)
```

If there are not enough review cards, backend may fill with new words. If there are not enough eligible new words, backend may return fewer items or fill with due review cards.

### Learned words

Every learning attempt must be stored. If a learner studies the same word 100 times, backend keeps 100 study events.

The event log is append-only:

```text
study_events
├─ event 1: word A, easy, 2026-05-05T10:00Z
├─ event 2: word A, hard, 2026-05-06T10:00Z
├─ event 3: word A, easy, 2026-05-07T10:00Z
└─ ...
```

Separately, backend maintains the latest per-user word state for efficient selection.

### Cached words on user devices

Backend must know which server words are currently cached on the user's device so it does not return duplicates already sitting in local storage.

Mobile should report local cache state to backend. This can be done in one of two ways:

1. Include `cached_server_word_ids` in the card request for small batches.
2. Add a dedicated cache sync endpoint for up to 1000 local word IDs.

For this project, a dedicated cache sync endpoint is cleaner because local cache can contain up to 1000 words.

```text
Mobile local DB                    Backend
┌──────────────────┐               ┌────────────────────┐
│ local_words      │               │ user_cached_words  │
│ server_word_id A │── sync list ──▶│ user/device, A     │
│ server_word_id B │               │ user/device, B     │
│ server_word_id C │               │ user/device, C     │
└──────────────────┘               └────────────────────┘
```

### Easy rating semantics

The requested behavior changes the meaning of `easy` compared with the current local implementation.

Target behavior:

- When the user presses `easy`, mobile creates a study event.
- Backend stores that event.
- Backend marks the word as no longer eligible as a new card for that user/device.
- Mobile removes that word from local database.
- Mobile requests or receives a replacement card.

This implies `easy` means "learned enough to remove from the active local set" for the current product flow. The word remains in backend history and may be used for analytics, but should not be returned again as a new word for that learner.

Open nuance: whether an `easy` word can ever return as review later. The strict reading of "không trả ra cho user đó nữa" means no. If we want spaced repetition later, use a different rating such as `too_easy` or an explicit `mastered` action.

## Proposed Architecture

```text
                         ┌────────────────────────┐
                         │ Backend Scheduler       │
                         │ - every minute if <1000 │
                         │ - daily +10 if >=1000   │
                         └───────────┬────────────┘
                                     │
                                     ▼
┌──────────────┐          ┌────────────────────────┐
│ LiteLLM / AI │◀────────▶│ Vocabulary Generator   │
└──────────────┘          │ validate + deduplicate │
                          └───────────┬────────────┘
                                      │
                                      ▼
                          ┌────────────────────────┐
                          │ words                  │
                          │ global vocabulary pool │
                          └───────────┬────────────┘
                                      │
            ┌─────────────────────────┼─────────────────────────┐
            ▼                         ▼                         ▼
┌────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│ study_events       │     │ user_word_states   │     │ user_cached_words  │
│ append-only log    │     │ latest state       │     │ local inventory    │
└────────────────────┘     └────────────────────┘     └────────────────────┘
            ▲                         ▲                         ▲
            │                         │                         │
            └────────────── Mobile sync / card APIs ────────────┘
```

## Backend Components

### 1. Vocabulary pool scheduler

Responsibilities:

- Count usable words per language.
- Decide whether generation is needed.
- Acquire a scheduler lock so only one backend instance generates at a time.
- Call `VocabularyGenerationService`.
- Record generation attempts, accepted count, rejected count, and errors.

State machine:

```text
┌──────────────┐
│ idle         │
└──────┬───────┘
       │ tick
       ▼
┌──────────────┐       pool >= target and daily done
│ inspect pool │─────────────────────────────────────┐
└──────┬───────┘                                     │
       │ needs generation                            │
       ▼                                             │
┌──────────────┐                                     │
│ acquire lock │                                     │
└──────┬───────┘                                     │
       │ lock acquired                               │
       ▼                                             │
┌──────────────┐       failure                       │
│ call AI      │──────────────┐                      │
└──────┬───────┘              │                      │
       │ accepted words       ▼                      │
       ▼              ┌──────────────┐               │
┌──────────────┐      │ log + retry  │               │
│ insert words │      │ next tick    │               │
└──────┬───────┘      └──────┬───────┘               │
       │                     │                       │
       ▼                     ▼                       ▼
┌────────────────────────────────────────────────────────┐
│ idle                                                   │
└────────────────────────────────────────────────────────┘
```

### 2. Card selection service

Responsibilities:

- Resolve learner identity: signed-in `user_id` if available, otherwise `device_id`.
- Read cached word IDs from `user_cached_words`.
- Read learned/mastered states from `user_word_states`.
- Select review and new cards using the configured ratio.
- Return only DB-backed words, never AI-generated during the request.

Selection inputs:

| Input | Source |
|---|---|
| `user_id` | bearer session, optional |
| `device_id` | request body/query, required for anonymous learning |
| `target_language` | request, default backend config |
| `limit` | request, capped |
| `new_ratio` | backend config, default `0.15` |
| cached exclusions | `user_cached_words` |
| learned/mastered exclusions | `user_word_states` |
| review due states | `user_word_states.next_review_at <= now` |

Selection sketch:

```text
requested limit = N
new_target = round(N * 0.15)
review_target = N - new_target

1. Select due review words:
   - user/device owns state
   - status is learning/review
   - next_review_at <= now
   - not already cached if backend is sending replacement batch

2. Select new words:
   - language matches
   - not in user_word_states as learned/mastered
   - not in user_cached_words
   - not in explicit exclude list

3. Fill shortages:
   - if review shortage, fill with eligible new words
   - if new shortage, fill with review words
   - if both shortage, return fewer items with metadata
```

### 3. Study event ingestion

Current `study_events` table already supports append-only storage. The backend should keep that behavior and add/maintain latest state.

On every accepted event:

```text
POST /v1/study-events or /v1/study-events/sync
        │
        ▼
insert study_events row
        │
        ▼
upsert user_word_states
        │
        ├─ easy      -> mastered/excluded from new, optionally removed from active cache
        ├─ hard      -> review, next_review_at soon
        ├─ too_hard  -> learning, next_review_at sooner
        └─ too_easy  -> mastered, excluded from new
```

The exact schedule can remain simple initially:

| Rating | Suggested state | Suggested next review |
|---|---|---|
| `easy` | `mastered` | none, do not return again |
| `too_easy` | `mastered` | none, do not return again |
| `hard` | `review` | tomorrow |
| `too_hard` | `learning` | in 5 minutes |

This differs from current mobile behavior where `easy` becomes `review` after 3 days. The new product request favors removal/replacement on `easy`.

### 4. Cache inventory sync

Mobile should tell backend what it currently stores locally.

Suggested endpoint:

```http
PUT /v1/user-word-cache
Authorization: Bearer session_... optional
Content-Type: application/json
```

Request:

```json
{
  "device_id": "device_abc",
  "server_word_ids": ["word_1", "word_2", "word_3"],
  "observed_at": "2026-05-05T10:00:00.000Z"
}
```

Behavior:

- Replace backend cache inventory for that user/device with the submitted list.
- Cap accepted list at 1000 IDs.
- Ignore IDs that do not exist in `words`.
- Use this inventory to avoid duplicate card selection.

When mobile deletes a word after `easy`, it can either:

- call this endpoint with the full updated cache list, or
- call a smaller mutation endpoint such as `DELETE /v1/user-word-cache/:word_id`.

For simplicity and consistency, full cache sync is safer.

## Database Model

Existing tables:

- `words`: global vocabulary pool.
- `study_events`: append-only learning attempts.
- `user_word_states`: already present in schema, suitable for latest per-user/device word state.

Recommended additions or clarifications:

### `generation_runs`

Tracks scheduler runs and AI health.

| Column | Meaning |
|---|---|
| `id` | run id |
| `language` | target language |
| `mode` | `fill_pool` or `daily_top_up` |
| `requested_count` | how many words scheduler wanted |
| `accepted_count` | inserted words |
| `rejected_count` | generated but invalid/duplicate |
| `error` | nullable failure message |
| `started_at` | run start |
| `finished_at` | run finish |

### `scheduler_locks`

Prevents multiple backend instances from generating simultaneously.

| Column | Meaning |
|---|---|
| `name` | lock key, e.g. `vocab_generation:en` |
| `owner_id` | backend instance id |
| `expires_at` | stale lock timeout |
| `updated_at` | heartbeat |

Postgres advisory locks are also valid and may be simpler than a table.

### `user_cached_words`

Stores active local cache inventory.

| Column | Meaning |
|---|---|
| `user_id` | nullable signed-in user |
| `device_id` | device identity |
| `word_id` | cached server word |
| `cached_at` | when backend learned it is cached |
| `last_reported_at` | latest inventory sync |

Recommended unique key:

```text
UNIQUE (device_id, word_id)
```

If signed-in state must merge across devices, also query by `user_id`.

### `user_word_states`

Use this table as the latest state projection.

Recommended uniqueness:

```text
UNIQUE (device_id, word_id)
```

For signed-in users, the implementation should decide whether `user_id` owns state across devices. Product-wise, signed-in learning should follow the user, not only the device, so the final design may need:

```text
UNIQUE (user_id, word_id) WHERE user_id IS NOT NULL
UNIQUE (device_id, word_id) WHERE user_id IS NULL
```

## API Surface

### Keep `GET /v1/words/next` as compatibility endpoint

The existing endpoint can remain for compatibility, but its behavior should change:

- It must not call AI.
- It should select from DB only.
- It preserves the previous response shape and exclusion/proficiency filters.

Because the product now asks for a 15%/85% mix, the batch-oriented endpoint is
the preferred refill API:

```http
GET /v1/learning/cards?limit=20&device_id=device_abc&target_language=en
```

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
      "card_type": "new",
      "selection_reason": "new_available"
    },
    {
      "server_word_id": "word_456",
      "term": "review",
      "card_type": "review",
      "selection_reason": "due_review"
    }
  ]
}
```

Implemented `selection_reason` values include `new_available`, `due_review`,
`review_shortage_fallback`, and `new_shortage_fallback`.

### Study events

Keep current endpoints:

- `POST /v1/study-events`
- `POST /v1/study-events/sync`

Add backend-side state projection after insert. Event acceptance must remain idempotent by `client_event_id`.

### Cache sync

Add:

- `PUT /v1/user-word-cache`

Potential future endpoint:

- `DELETE /v1/user-word-cache/:word_id`

## Mobile Behavior Contract

Mobile remains responsible for local offline experience, but backend becomes the source of truth for what should not be returned again.

### On app startup

1. Load or create `device_id`.
2. Load signed-in session if present.
3. Sync current local cache inventory to backend.
4. Request a batch of cards if local active cards are below threshold.

### On card request

Mobile should prefer local cards for instant UX, but refill from backend in batches.

```text
User needs next card
      │
      ▼
Local selector chooses from local cache
      │
      ├─ if enough local cards: show immediately
      │
      └─ if below threshold:
             request backend card batch
             upsert local_words
             show local card
```

### On `easy`

1. Insert local study event.
2. Remove the word from `local_words`.
3. Queue/sync study event to backend.
4. Sync cache inventory or send cache removal.
5. Show replacement card from local cache.
6. If local cache is below threshold, request backend batch.

The event must be preserved even though the word is removed from local cache.

## Interaction With Existing `mobile-vocabulary-prefetch-refresh`

The active `mobile-vocabulary-prefetch-refresh` change currently assumes mobile pulls recent words and manages a 1000-word local cache proactively. The new backend-first design changes the responsibility split:

| Concern | Current active change direction | New desired direction |
|---|---|---|
| AI generation | Backend on-demand or existing pool | Backend scheduler only |
| 1000-word target | Mobile local cache target | Backend vocabulary pool minimum |
| Daily refresh | Mobile fetches ~150/day | Backend generates +10/day after pool full |
| Duplicate avoidance | Mobile exclude/filter local IDs | Backend stores local cache inventory |
| New/review mix | Mobile local selection | Backend card selection target 15/85 |

This does not make the mobile change useless, but it should be narrowed:

- Keep local cache, offline queue, and local UX.
- Remove the assumption that mobile owns daily vocabulary freshness.
- Add cache inventory sync and backend batch card refill.

## Risks and Design Questions

### 1. Does `easy` really mean "never return again"?

The request says easy words should not be returned for that user again. That is simple and matches removal from local DB, but it reduces spaced repetition value. If the learning model later needs long-term review, use `mastered` with a very long interval rather than permanent exclusion.

### 2. What happens when a new anonymous user later signs in?

Device-level state should be mergeable into user-level state:

```text
anonymous device history + user login
        │
        ▼
attach device study_events to user_id where possible
merge user_word_states
preserve user_cached_words for that device
```

### 3. How much should backend trust mobile cache inventory?

Mobile inventory is advisory for duplicate avoidance, not security. Backend can accept it because the worst case is suboptimal card selection for that user/device.

### 4. Should the pool be 1000 total or 1000 per language/level?

The more useful definition is per target language, optionally per difficulty distribution. A single global 1000-word pool can starve some CEFR levels.

Suggested initial target:

```text
1000 words per target language, distributed across CEFR levels.
```

### 5. What if AI generates poor or duplicated content?

Keep validation and dedupe. Add generation telemetry and review tooling later. Do not return unvalidated AI output directly to mobile.

## Suggested Phased Plan

### Phase 1: Backend generation decoupling

- Implemented: AI calls are removed from `/v1/words/next`.
- Implemented: scheduler fills `words` to the configured minimum.
- Implemented: scheduler performs daily top-up after pool is full.
- Implemented: generation run logging and ownership locking are in the store
  contract and PostgreSQL schema.

### Phase 2: Backend selection state

- Implemented: accepted study events project latest `user_word_states`.
- Implemented: `user_cached_words` and `PUT /v1/user-word-cache`.
- Implemented: new-card selection excludes completed and cached words.

### Phase 3: 15/85 card batch API

- Implemented: `GET /v1/learning/cards`.
- Implemented: per-batch target mix of 15% new / 85% review with shortage
  fallback.
- Implemented: target/actual mix and per-card selection metadata.

### Phase 4: Mobile integration

- Implemented: API client and repository support cache inventory sync.
- Implemented: API client and repository support backend-selected card refill.
- Implemented: `easy` inserts the local study event before deleting the local
  word and then syncs cache inventory.

Note: the older `VocabularyRefreshWorker` remains in the codebase as an
offline/local-cache fallback. Product freshness is now backend-owned; mobile
daily/prefetch behavior should be treated as cache warmup, not as the source of
global vocabulary growth.

## Acceptance Criteria

- Mobile requests never trigger AI generation.
- With fewer than 1000 words in the database, backend attempts generation every minute until target is reached.
- With at least 1000 words, backend generates 10 new words per day.
- Every study attempt is stored as a distinct `study_events` row.
- Latest word state is projected into `user_word_states`.
- Backend knows the device's active local cache and avoids returning those words again.
- Words marked `easy` are removed from mobile local DB and excluded from future new-card selection for that learner.
- Card batches target 15% new and 85% review, with documented fallback behavior when either pool is insufficient.
- The system works for anonymous users by `device_id` and signed-in users by `user_id`, with a clear merge path after login.

## OpenSpec Follow-up

This is substantial enough to deserve a new OpenSpec change or a rewrite of `mobile-vocabulary-prefetch-refresh` before implementation. A good change name would be:

```text
backend-managed-vocabulary-pool-selection
```

Suggested modified capabilities:

- `backend-vocabulary-generation`
- `backend-learning-card-selection`
- `mobile-local-cache-sync`
- `mobile-learning-session`
