# 2026-05-07 Mobile Backend Request Investigation

## Question

When the mobile app starts, backend logs do not show requests that load data.
Mobile logs show:

```text
No local new word is available.
```

This investigation is read-only for app/backend code. No implementation changes
were made.

## Short Answer

The observed mobile log is produced by the local lookup path, not by a failed
backend `/v1/learning/cards` response. In the current code,
`showNewWord()` calls `WordRepository.getNewWordWithFallbackResult()`, and that
method only checks `LocalDatabase.nextNewWord()`. If local storage has no
eligible `newWord`, it logs `new_word.local.empty` and returns `none` without
calling the backend.

So, for the exact symptom "No local new word is available" plus no backend
`/v1/learning/cards` logs, the most likely explanation is:

```text
Mobile screen load/swipe
  -> showNewWord()
  -> getNewWordWithFallbackResult()
  -> LocalDatabase.nextNewWord()
  -> null
  -> log "No local new word is available."
  -> no backend request in this path
```

Backend fetches are now expected from startup/top-up paths, not from every
visible "new word" request.

## Current Data Flow

```text
main()
  |
  |-- repository.syncCacheInventory(deviceId)     PUT /v1/user-word-cache
  |
  |-- if local total == 0
  |     await repository.topUpInventoryIfNeeded()
  |       -> refillLearningCards()
  |          -> apiClient.fetchLearningCards()     POST /v1/learning/cards
  |
  |-- else
  |     unawaited(repository.topUpInventoryIfNeeded())
  |
  v
runApp()
  |
  v
LearningSessionController.loadInitial()
  |
  |-- repository.fetchProficiency()               GET /v1/proficiency
  |
  |-- showNewWord()
        |
        v
      getNewWordWithFallbackResult()
        |
        |-- database.nextNewWord()
        |
        |-- if empty: log new_word.local.empty
        |
        '-- no backend call here
```

Important consequence: if startup/top-up did not populate local ObjectBox first,
the screen can show "No local new word is available" without producing any
backend `/v1/learning/cards` request at that moment.

## Evidence

### 1. The mobile log comes from local-only lookup

`mobile/lib/src/data/word_repository.dart`:

- Lines 207-210: `getNewWordWithFallbackResult()` calls
  `database.nextNewWord(language: language)`.
- Lines 226-230: when the local lookup misses, it logs
  `event: 'new_word.local.empty'` and message
  `No local new word is available.`
- Lines 231-235: it returns `WordLookupSource.none`.
- There is no call to `apiClient.fetchLearningCards()` in this method.

The backend refill method exists separately:

- Lines 298-309: `refillLearningCards()` calls
  `apiClient.fetchLearningCards(...)`.

### 2. The UI path calls that local-only lookup

`mobile/lib/src/session/learning_session_controller.dart`:

- Lines 94-109: `loadInitial()` eventually calls `showNewWord()`.
- Lines 227-273: `showNewWord()` calls
  `repository.getNewWordWithFallbackResult(...)`, then falls back to a review
  word if no new word exists.
- There is no top-up or prefetch trigger at the end of `showNewWord()`.
- Lines 384-399: top-up exists only on an hourly timer after initial load.

### 3. Startup top-up can be skipped before reaching `/v1/learning/cards`

`mobile/lib/main.dart`:

- Lines 47-50: app awaits `repository.syncCacheInventory(deviceId)` first.
- Lines 51-55: only after cache sync succeeds does it check local total and
  call `topUpInventoryIfNeeded()` for an empty DB.
- Lines 58-64: any error in that block is caught and logged as
  `app.refresh.init_error`, then app continues to `runApp()`.

That means a failed `PUT /v1/user-word-cache` can prevent the first-install
`POST /v1/learning/cards` attempt entirely.

### 4. Backend request logging does exist for `/v1`

`backend/src/app.js`:

- Lines 357-368: `/v1` requests log `request_started`.
- Lines 370-378: completed `/v1` responses log `request_completed`.
- Lines 137-175: `/v1/learning/cards` is the current learning-card endpoint.

So if the mobile app actually reaches the local backend under `/v1`, the backend
should show structured request logs. Absence of those logs strongly suggests
one of these:

- the mobile app is not pointing at that backend;
- the backend is not running/listening where expected;
- the request is happening against another environment, likely production;
- the path that produced the mobile log did not call backend at all.

### 5. Local backend is not running in this workspace right now

Observed command results:

```text
docker compose ps
NAME      IMAGE     COMMAND   SERVICE   CREATED   STATUS    PORTS
```

```text
curl http://localhost:8787/health
curl: (7) Failed to connect to localhost port 8787
```

If the app was expected to hit this local backend, there is currently no service
listening on `localhost:8787` from this workspace.

### 6. Backend URL may not be local

`mobile/lib/src/config.dart`:

- Lines 21-24: default `BACKEND_BASE_URL` is `<YOUR_BACKEND_URL>`.

Docs vary by context:

- `README.md` uses `<YOUR_BACKEND_URL>` in the sample run command.
- `mobile/README.md` uses `http://localhost:8787`.
- `docs/mvp-setup.md` uses `http://localhost:8787`.

For Android emulator specifically, `http://localhost:8787` points at the
emulator itself, not the host machine. The host backend is normally reached via
`http://10.0.2.2:8787`. If the app was built without a local
`--dart-define=BACKEND_BASE_URL=...`, it will use production by default.

### 7. Credential mismatch can cause a different failure

`mobile/lib/src/config.dart` defaults:

```text
APP_CREDENTIAL_APP_ID=expat8-mobile-app
APP_CREDENTIAL_SECRET=<YOUR_APP_SECRET>
```

`backend/.env.example` uses:

```text
APP_CREDENTIALS_JSON=[{"appId":"app_mobile_dev","secret":"dev-secret-change-me","status":"active"}]
```

If the mobile app reaches a local backend configured from `.env.example` but the
app uses its default credentials, `/v1/*` calls will be rejected. In that case
the backend should still show `request_started` and `request_completed` logs,
usually with `400`.

This credential mismatch does not explain "no backend logs at all", but it is a
likely next failure after URL/routing is fixed.

## OpenSpec Drift

There is active spec drift around when mobile should call the backend.

`openspec/changes/swipe-local-prefetch-prune/specs/swipe-auto-prefetch/spec.md`
says:

- after every swipe, check unlearned word count;
- if count is below 100, trigger background prefetch of up to 100 new words.

`openspec/changes/swipe-local-prefetch-prune/tasks.md` marks those controller
prefetch tasks as complete, but the current controller no longer has
`_triggerPrefetchIfNeeded()` and no longer calls prefetch after `showNewWord()`
or `showRecentReview()`.

There is also an older `offline-first-100-word-batch` design note saying user
activities should only read/write local ObjectBox and should not call backend
during swipe. That idea is compatible with background top-up, but the live code
currently has no per-swipe low-watermark prefetch trigger.

Current behavior therefore matches "local-first/offline-first card display",
but does not match the active `swipe-local-prefetch-prune` requirement that
backend prefetch should happen after swipe when local unlearned words are low.

## Hypotheses Ranked

### H1: Expected behavior is being misread as backend failure

High confidence.

The specific mobile message comes from a local-only branch. It does not imply a
backend request was attempted. If local ObjectBox is empty, the controller can
show this message without backend `/v1/learning/cards` activity.

### H2: Startup/top-up did not populate local cache

High confidence.

Possible causes:

- local backend is not running;
- mobile points to production instead of local backend;
- Android emulator uses `localhost` incorrectly;
- `syncCacheInventory()` failed before first-install top-up ran;
- app credentials do not match backend config;
- backend returned an empty batch or failed generation.

### H3: Code regression removed swipe-time prefetch

Medium/high confidence.

Git diff shows earlier code had `_triggerPrefetchIfNeeded()` and
`prefetchBatch()` paths. Current code removed those and replaced them with
startup/hourly `topUpInventoryIfNeeded()`. That explains why repeated swipes may
not trigger backend logs even when the local new-word pool is exhausted.

### H4: Backend logging is broken

Low confidence.

Backend `/v1` middleware logs start/completion. If `/v1/learning/cards` is hit,
logs should appear. The more likely issue is the request never reaches that
backend, or the mobile branch never calls it.

## What To Check Next

1. Confirm what backend URL the running app was built with:

```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=http://10.0.2.2:8787 \
  --dart-define=APP_CREDENTIAL_APP_ID=app_mobile_dev \
  --dart-define=APP_CREDENTIAL_SECRET=dev-secret-change-me \
  --dart-define=APP_LOG_LEVEL=debug
```

Use `http://localhost:8787` only for desktop/web cases where the app process is
running on the host machine.

2. Start and confirm backend locally:

```bash
docker compose up --build
curl http://localhost:8787/health
docker compose logs -f backend
```

3. In mobile logs, search around startup for:

```text
app.refresh.init_error
inventory.refill.failed
cache_inventory.sync
learning_cards.refill
proficiency.request
proficiency.response
new_word.local.empty
```

4. If local backend receives `PUT /v1/user-word-cache` but not
`POST /v1/learning/cards`, inspect whether `syncCacheInventory()` failed and
short-circuited the startup block.

5. If local backend receives nothing, treat it as a URL/emulator/network/build
configuration problem before investigating backend selection.

## Verification Attempt

I attempted to run the relevant Flutter tests:

```bash
flutter test test/word_repository_test.dart test/learning_session_controller_test.dart
```

The environment failed before test execution:

```text
snap-confine is packaged without necessary permissions and cannot continue
required permitted capability cap_dac_override not found in current capabilities:
  =
```

So this report is based on code tracing, OpenSpec artifacts, docs, and local
backend process checks, not on a successful test run.

## Bottom Line

The backend is not expected to log a `/v1/learning/cards` request when the app
prints `No local new word is available`, because the current new-card display
path does not call the backend. The real issue is earlier in the pipeline:
local cache population/top-up is not happening, is happening against another
backend, or is failing before `/v1/learning/cards` is reached.

The active specs also appear out of sync with current code: they say swipe
should trigger low-watermark background prefetch, while the live controller now
only has startup and hourly top-up.
