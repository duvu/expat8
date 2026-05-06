# Expat8 — Tài liệu Luồng End-to-End

> Cập nhật: 2026-05-06  
> Phạm vi: backend (Node.js/Express + PostgreSQL) + mobile (Flutter/Dart + ObjectBox)

---

## Mục lục

1. [Kiến trúc tổng quan](#1-kiến-trúc-tổng-quan)
2. [Bảo mật chung — App Credential & User Session](#2-bảo-mật-chung--app-credential--user-session)
3. [Khởi động ứng dụng (App Startup)](#3-khởi-động-ứng-dụng-app-startup)
4. [Luồng học từ — Hiển thị thẻ (Card Display)](#4-luồng-học-từ--hiển-thị-thẻ-card-display)
5. [Luồng cử chỉ học (Gesture Actions)](#5-luồng-cử-chỉ-học-gesture-actions)
6. [Luồng đánh giá từ — Rating (rateCurrent)](#6-luồng-đánh-giá-từ--rating-ratecurrent)
7. [Luồng đồng bộ sự kiện học (Study Event Sync)](#7-luồng-đồng-bộ-sự-kiện-học-study-event-sync)
8. [Luồng nạp thêm từ (Vocabulary Refill)](#8-luồng-nạp-thêm-từ-vocabulary-refill)
9. [Luồng sinh từ tự động trên backend (Vocabulary Generation Scheduler)](#9-luồng-sinh-từ-tự-động-trên-backend-vocabulary-generation-scheduler)
10. [Luồng đồng bộ cache inventory](#10-luồng-đồng-bộ-cache-inventory)
11. [Luồng xác thực người dùng (Auth Flows)](#11-luồng-xác-thực-người-dùng-auth-flows)
12. [Luồng Proficiency — CEFR level tracking](#12-luồng-proficiency--cefr-level-tracking)
13. [Luồng dự phòng offline (Offline Fallback)](#13-luồng-dự-phòng-offline-offline-fallback)
14. [Logging & Telemetry](#14-logging--telemetry)
15. [Database — Backend Schema (PostgreSQL)](#15-database--backend-schema-postgresql)
16. [Database — Mobile Local Store (ObjectBox)](#16-database--mobile-local-store-objectbox)
17. [Cấu hình môi trường](#17-cấu-hình-môi-trường)

---

## 1. Kiến trúc tổng quan

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter Mobile App                                          │
│                                                              │
│  LearningScreen (UI)                                         │
│       │ gesture / tap                                        │
│       ▼                                                      │
│  LearningSessionController (state management, ChangeNotifier)│
│       │                                                      │
│  ┌────┴───────────────────────────────┐                      │
│  │  WordRepository                    │                      │
│  │  ├── LocalDatabase (ObjectBox)     │                      │
│  │  │   ├── LocalWordEntity           │                      │
│  │  │   ├── StudyEventEntity          │                      │
│  │  │   ├── SyncQueueEntity           │                      │
│  │  │   └── AppSettingEntity          │                      │
│  │  └── BackendApiClient              │                      │
│  │       └── HMAC-SHA256 signed HTTP  │                      │
│  └────────────────────────────────────┘                      │
│       │                                                      │
│  SyncWorker (background, on-demand)                          │
└─────────────────────────────────────────────────────────────┘
                          │  HTTPS (signed)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Backend — Express.js                                        │
│                                                              │
│  Middlewares (theo thứ tự):                                  │
│  1. CORS (preflight trước mọi thứ)                           │
│  2. requestContextMiddleware (request ID, logger child)      │
│  3. rejectMissingCredentialHeaders                           │
│  4. captureRawBody                                           │
│  5. appCredentialGuard (HMAC verify, nonce check, replay)    │
│  6. parseJsonFromCapturedBody                                │
│  7. V1 Router (routes)                                       │
│                                                              │
│  Routes:                                                     │
│  POST /v1/users/register                                     │
│  POST /v1/users/sign-in                                      │
│  POST /v1/users/sign-out                                     │
│  POST /v1/learning/cards                                     │
│  GET  /v1/words/recent                                       │
│  POST /v1/study-events                                       │
│  POST /v1/study-events/sync                                  │
│  PUT  /v1/user-word-cache                                    │
│  GET  /v1/proficiency                                        │
│  GET  /health                                                │
│                                                              │
│  WordStore / PostgresWordStore                               │
│  VocabularyGenerationService → LiteLLM                       │
│  VocabularyPoolScheduler (setInterval)                       │
│                                                              │
│  PostgreSQL                                                  │
│  ├── words                                                   │
│  ├── study_events                                            │
│  ├── user_proficiency                                        │
│  ├── user_word_states                                        │
│  ├── user_cached_words                                       │
│  ├── users                                                   │
│  ├── user_sessions                                           │
│  ├── generation_runs                                         │
│  └── scheduler_locks                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Bảo mật chung — App Credential & User Session

### 2.1 App Credential (bắt buộc mọi `/v1/*` request)

Mỗi request từ mobile gửi các header:

```
X-Expat8-App-Id: app_mobile_prod
X-Expat8-Timestamp: 2026-05-06T10:00:00.000Z
X-Expat8-Nonce: <128-bit random hex>
X-Expat8-Content-SHA256: base64url(sha256(raw_body))
X-Expat8-Signature: v1=base64url(hmac_sha256(secret, canonical_request))
```

**Canonical request** dùng để ký:
```
v1
METHOD
PATH_WITH_SORTED_QUERY
TIMESTAMP
NONCE
CONTENT_SHA256
```

**Mobile tạo nonce**: `crypto.randomBytes(16)` — entropy cao, không phải timestamp. Tất cả concurrent requests có nonce riêng biệt.

**Backend kiểm tra (theo thứ tự)**:
1. Tất cả 5 header phải có mặt
2. `Content-SHA256` khớp với hash của raw body
3. Timestamp không lệch quá `APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS` (default 300s)
4. `App-Id` tồn tại và `status = 'active'` trong config
5. Tính lại signature, so sánh timing-safe
6. Nonce chưa dùng (InMemoryNonceCache), sau đó mark đã dùng với TTL

**Lỗi**: trả về `400 { "error": "bad_request" }` ở mọi bước.

**CORS preflight**: `OPTIONS /v1/*` được xử lý **trước** raw-body capture và app credential guard. Backend trả `204` với headers CORS cho phép `x-expat8-*` headers.

### 2.2 User Session (tuỳ chọn)

Signed-in request thêm header:
```
Authorization: Bearer <session_token>
```

Backend gọi `resolveOptionalUserSession()`:
- Không có token → `userSession = null` (anonymous, tiếp tục)
- Token không hợp lệ → `401 { "error": "invalid_session" }` (dừng)
- Token hợp lệ → trả về session object (chứa `user.id`)

Khi signed-in, backend dùng `userId` thay vì `deviceId` cho:
- Proficiency lookup
- Learned-word exclusion khi select thẻ
- Study event association

---

## 3. Khởi động ứng dụng (App Startup)

**File**: `mobile/lib/main.dart`

```
main()
  │
  ├── LocalDatabase.open()                    (mở ObjectBox store)
  ├── PersistedLogger(write → persistLogEntry)
  ├── BackendApiClient(baseUrl, appId, secret)
  ├── WordRepository(database, apiClient)
  ├── LearningSessionController(repository)
  │
  ├── repository.getOrCreateDeviceId()        → "anonymous_<uuid-v4>"
  ├── repository.initRefreshWorker(deviceId)  → lưu _refillDeviceId
  ├── repository.syncCacheInventory(deviceId) → PUT /v1/user-word-cache
  │
  ├── database.countUnstudiedNewWords()
  │    IF count < 10:
  │    └── await repository.prefetchBatch()   → POST /v1/learning/cards (limit=100)
  │
  ├── unawaited repository.checkAndRunFirstInstallPrefetch()
  │    → getSetting("is_prefetch_done")
  │      IF "true": skip
  │      IF null/false: _runBackendManagedRefill(limit=vocabPrefetchLimit)
  │
  ├── unawaited repository.checkAndRunDailyRefresh()
  │    → getSetting("last_daily_refresh_date")
  │      IF today: skip
  │      IF countUnstudiedNewWords >= 100: skip, mark today
  │      ELSE: _runBackendManagedRefill(limit=100, markDailyRefreshDate=today)
  │
  └── runApp(LanguageLearningApp → LearningScreen)
           └── controller.loadInitial()
                ├── getOrCreateDeviceId()
                ├── loadUserSession() → từ ObjectBox AppSettingEntity
                ├── fetchProficiency(deviceId) → GET /v1/proficiency
                └── showNewWord()
```

**Device ID format**: `anonymous_<uuid-v4>`. Nếu ID cũ không có prefix `anonymous_`, tự động normalize khi đọc.

---

## 4. Luồng học từ — Hiển thị thẻ (Card Display)

### 4.1 Lấy thẻ mới (`showNewWord`)

```
showNewWord()
  │
  ├── repository.getNewWordWithFallbackResult(deviceId)
  │    │
  │    ├── database.countUnstudiedNewWords()
  │    │    IF count < vocabProactiveMinNew (default 15):
  │    │    └── refillLearningCards(deviceId, limit=15)
  │    │         ├── apiClient.fetchLearningCards(deviceId, limit, sessionToken)
  │    │         │    POST /v1/learning/cards
  │    │         │    body: { device_id, target_language, limit, card_mode: "new" }
  │    │         ├── database.addBatch(items)   (cap 1000, prune nếu cần)
  │    │         └── syncCacheInventory(deviceId)
  │    │
  │    ├── database.nextNewWord()
  │    │    → query ObjectBox: status = "new", order by createdAt DESC
  │    │
  │    NẾUNGĐƯỢC:
  │    └── return WordLookupResult(word, source=backend|localFallback)
  │
  NẾUKHÔNGCÓ từ mới:
  ├── repository.getReviewWord(now)
  │    → database.nextDueReviewWord(now): status IN (learning, review, mastered)
  │      AND nextReviewAt <= now, sort by nextReviewAt ASC
  │
  └── _showWord(word, CardKind.newWord|review, emptyMessage)
       → currentWord = word; isLoading = false; notifyListeners()
```

### 4.2 Lấy thẻ review (`showRecentReview`)

```
showRecentReview()
  │
  ├── repository.getRecentReviewWordResult(now)
  │    ├── database.recentlyLearnedReviewWord()
  │    │    → status IN (learning, review, mastered), lastSeenAt NOT NULL
  │    │      sort by lastSeenAt DESC
  │    │
  │    IF không có recently learned:
  │    └── database.nextDueReviewWord(now)
  │
  IF không có review word:
  └── repository.getNewWordWithFallbackResult(deviceId) (fallback)
```

### 4.3 Chọn thẻ theo bias (`_showBiasedCard`)

```
_showBiasedCard(newWordPercent, reviewPercent)
  │
  ├── random = now.millisecond % 100
  │
  ├── IF random < reviewPercent:
  │    ├── repository.getDifficultRelearnWord(now)
  │    │    → status = "learning" AND nextReviewAt <= now, sort by nextReviewAt ASC
  │    └── IF null: showRecentReview()
  │
  └── IF random >= reviewPercent:
       └── showNewWord()
```

**Swipe mapping**:
| Gesture | newWordPercent | reviewPercent |
|---------|---------------|---------------|
| `nextCard()` (default) | 30% | 70% |
| Swipe Right→Left | 85% | 15% |
| Swipe Left→Right | 15% | 85% |

### 4.4 Backend: `POST /v1/learning/cards`

```
Validation:
  - device_id: required string
  - card_mode: phải là "new" hoặc null/empty → 400 nếu là giá trị khác
  - Không có client-side exclusion fields → 400 nếu có

resolveOptionalUserSession() → userSession | null | false(401)

store.learningCards(deviceId, userId, targetLanguage, limit, now)
  → Select words: exclude cached by owner + exclude user/device word states
  → InMemoryWordStore: filter from in-memory words map
  → PostgresWordStore: query với JOIN user_word_states, user_cached_words

IF items.length < limit AND generationService != null:
  → generationService.generateAndStore(targetLanguage, shortfall)
  → gọi lại store.learningCards() lần nữa

Response: { target_mix, actual_mix, items[...{ ...word, card_type, selection_reason }] }

Sau khi trả response, word IDs được persist vào user_cached_words (active claim).
```

---

## 5. Luồng cử chỉ học (Gesture Actions)

### 5.1 Swipe Bottom→Top (Remembered / "Easy review")

```
onSwipeBottomToTop()
  │
  ├── repository.markRememberedLowFrequency(word, now, deviceId)
  │    ├── database.markWordRememberedLowFrequency(word, now)
  │    │    → status = "review", nextReviewAt = now + interval * 0.1 (10% frequency)
  │    ├── recordWordStudied() → tăng counter, check proactive refill
  │    └── syncCacheInventory(deviceId)  [fire-and-forget, lỗi chỉ log]
  │
  ├── _triggerPrefetchIfNeeded()
  └── nextCard()
```

### 5.2 Swipe Top→Bottom (Difficult / "Hard relearn")

```
onSwipeTopToBottom()
  │
  ├── repository.markAsDifficultForRelearn(word, now, deviceId)
  │    ├── database.markWordDifficultForRelearn(word, now)
  │    │    → status = "learning", nextReviewAt = now + short interval
  │    ├── recordWordStudied()
  │    └── syncCacheInventory(deviceId)  [fire-and-forget]
  │
  ├── _triggerPrefetchIfNeeded()
  └── nextCard()
```

### 5.3 Low-watermark prefetch trigger (`_triggerPrefetchIfNeeded`)

```
_triggerPrefetchIfNeeded()
  IF _prefetchInFlight: return

  database.countUnstudiedNewWords().then(count)
    IF count <= 3:
      _prefetchInFlight = true
      repository.prefetchBatch() [unawaited]
        → apiClient.fetchLearningCards(deviceId, limit=100)
        → database.addBatch(items)
      .then: _prefetchInFlight = false
      .catchError: _prefetchInFlight = false
```

---

## 6. Luồng đánh giá từ — Rating (rateCurrent)

```
controller.rateCurrent(StudyRating rating)
  │
  ├── repository.recordRating(word, rating, now, deviceId)
  │    │
  │    ├── 1. Tạo StudyEvent(clientEventId=uuid, localWordId, serverWordId, rating, occurredAt)
  │    ├── 2. database.insertStudyEvent(event)
  │    │
  │    ├── 3a. IF rating == easy:
  │    │    ├── database.deleteLocalWord(localId)         (xóa khỏi local store)
  │    │    └── syncCacheInventory(deviceId) [fire-and-forget]
  │    │
  │    ├── 3b. IF rating != easy:
  │    │    └── database.updateWordAfterRating(word, rating, now)
  │    │         → cập nhật status, lastSeenAt, nextReviewAt, reviewCount
  │    │
  │    ├── 4. recordWordStudied()
  │    │    → tăng counter "words_studied_since_last_refresh"
  │    │      IF counter % vocabProactiveThreshold == 0:
  │    │        IF countUnstudiedNewWords < vocabProactiveMinNew:
  │    │          _runBackendManagedRefill(limit=vocabProactiveMinNew) [unawaited]
  │    │
  │    ├── 5. apiClient.submitStudyEvent(deviceId, event.toSyncJson(), sessionToken)
  │    │    POST /v1/study-events
  │    │    body: { device_id, language, client_event_id, server_word_id, local_word_id,
  │    │            rating, occurred_at }
  │    │
  │    ├── 6a. SUCCESS:
  │    │    ├── database.markEventSynced(clientEventId)
  │    │    └── return result.proficiency
  │    │
  │    └── 6b. FAIL (network/timeout):
  │         ├── log warning "rating.sync.deferred"
  │         └── return null  (event ở trong SyncQueueEntity chờ retry)
  │
  ├── IF proficiency changed: set _levelChangeMessage, log session.proficiency.changed
  ├── _triggerPrefetchIfNeeded()
  └── nextCard()
```

**Backend `POST /v1/study-events`**:
```
Validation: device_id, client_event_id, rating, occurred_at — tất cả required
requireStudyRating(rating) → InvalidStudyRatingError → 400 { "error": "invalid_rating" }

store.recordStudyEvent(deviceId, userId, language, event)
  → Insert study_events (upsert on conflict client_event_id)
  → Tính consecutive ratings:
      countConsecutiveRatings(deviceId|userId):
        - Đếm rating cùng loại liên tiếp từ mới nhất
        - isProgressionRating: "too_easy" → increment, "hard" → decrement
      IF consecutive >= 5:
        incrementLevel hoặc decrementLevel → update user_proficiency
        → level_changed = true
  → Upsert user_word_states (latest projection)

Response: { success, event_id, idempotent, proficiency: { level, level_changed, ... } }
```

---

## 7. Luồng đồng bộ sự kiện học (Study Event Sync)

Dùng khi event lần đầu submit thất bại, hoặc được gọi bởi SyncWorker.

### 7.1 SyncWorker

```
SyncWorker.runOnce()
  └── repository.syncPendingEvents(deviceId)
       │
       ├── database.dueSyncEntries(now)
       │    → query SyncQueueEntity: next_retry_at <= now
       │
       └── FOR each entry:
            ├── apiClient.syncStudyEvents(deviceId, [payload], sessionToken)
            │    POST /v1/study-events/sync
            │    body: { device_id, events: [{ client_event_id, server_word_id,
            │                                  local_word_id, rating, occurred_at }] }
            │
            ├── SUCCESS: database.markEventSynced(acceptedId)
            └── FAIL: database.scheduleRetry(entry, now)
                       → tăng attempt_count, set next_retry_at (exponential backoff)
```

### 7.2 Backend `POST /v1/study-events/sync`

```
Validation: device_id required
resolveOptionalUserSession()

store.syncStudyEvents(deviceId, userId, language, events[])
  → FOR each event:
      requireStudyRating(rating)
      Insert/upsert study_events
      Upsert user_word_states
  → Tính proficiency hiện tại sau khi xử lý batch
  → Trả về: { accepted_event_ids, rejected_events, proficiency }
```

---

## 8. Luồng nạp thêm từ (Vocabulary Refill)

### 8.1 `prefetchBatch` (low-watermark, startup)

```
repository.prefetchBatch(batchSize=100)
  ├── apiClient.fetchLearningCards(deviceId, limit=batchSize, sessionToken)
  │    POST /v1/learning/cards { device_id, limit, target_language, card_mode: "new" }
  └── database.addBatch(batch.items)
       → IF localWordCount >= 990: pruneToMostRecent(990) trước khi insert
       → upsert từng word (skip words có pending sync queue)
       → Tổng local words luôn <= 1000
```

### 8.2 `refillLearningCards` (proactive refill khi < threshold)

```
repository.refillLearningCards(deviceId, limit)
  ├── apiClient.fetchLearningCards(...)
  ├── database.addBatch(items)
  └── syncCacheInventory(deviceId) → PUT /v1/user-word-cache
```

### 8.3 `_runBackendManagedRefill` (daily refresh, first-install, proactive)

```
_runBackendManagedRefill(limit, markPrefetchDone?, markDailyRefreshDate?)
  ├── refillLearningCards(deviceId, limit)
  ├── IF markPrefetchDone: setSetting("is_prefetch_done", "true")
  └── IF markDailyRefreshDate: setSetting("last_daily_refresh_date", date)
  [FAIL: log warning, không rethrow]
```

### 8.4 Proactive refresh trigger

```
recordWordStudied()
  ├── counter = getSetting("words_studied_since_last_refresh") + 1
  ├── setSetting(counter)
  └── IF counter % vocabProactiveThreshold (default 100) == 0:
       countUnstudiedNewWords()
       IF count < vocabProactiveMinNew (default 15):
         _runBackendManagedRefill(limit=15) [unawaited]
```

---

## 9. Luồng sinh từ tự động trên backend (Vocabulary Generation Scheduler)

```
VocabularyPoolScheduler.start()
  └── setInterval(runOnce, vocabFillIntervalSeconds * 1000)  [default: 60s]

runOnce(targetLanguage)
  │
  ├── count = store.countUsableWords(targetLanguage)
  ├── poolMin = config.vocabPoolMinSize  (default 1000)
  │
  ├── mode = count < poolMin ? "fill" : "daily_top_up"
  │
  ├── IF mode == "daily_top_up":
  │    - IF now.getUTCHours() < vocabDailyGenerationHourUtc: → idle
  │    - IF hasGenerationRun(today, "daily_top_up"): → idle
  │
  ├── requestedCount:
  │    fill: min(vocabGenerationBatchSize=20, poolMin - count)
  │    daily_top_up: vocabDailyGenerationCount (default 10)
  │
  ├── acquireGenerationLock(targetLanguage, ownerId, ttl=120s)
  │    → PostgreSQL: INSERT ... ON CONFLICT DO UPDATE WHERE expires_at <= now
  │    → Chỉ 1 backend instance chạy tại 1 thời điểm
  │
  ├── generationService.generateAndStore(sourceLanguage, targetLanguage, limit)
  │    │
  │    ├── FOR attempt in [0,1,2] WHILE accepted.length < limit:
  │    │    ├── liteLLMClient.generateVocabulary(params)
  │    │    │    → POST đến LiteLLM proxy (lite.x51.vn)
  │    │    │    → model: gpt-4o-mini (default)
  │    │    │    → prompt: yêu cầu JSON array các từ với term, meaning_vi, ipa, ...
  │    │    │
  │    │    ├── parseVocabularyJson(raw): extract JSON từ response
  │    │    ├── validateVocabularyItem(candidate): check required fields
  │    │    └── store.insertWord(candidate)
  │    │         → ON CONFLICT (language, normalized_term) DO NOTHING
  │    │
  │    └── return accepted[]
  │
  ├── recordGenerationRun(status, requestedCount, insertedCount)
  └── releaseGenerationLock()
```

**Nếu khi mobile request `POST /v1/learning/cards` mà pool không đủ từ**:
```
shortfall = limit - result.items.length
IF shortfall > 0 AND generationService != null:
  → generationService.generateAndStore(targetLanguage, shortfall)
  → gọi lại store.learningCards() lần 2
```

---

## 10. Luồng đồng bộ cache inventory

```
repository.syncCacheInventory(deviceId)
  │
  ├── database.activeCachedServerWordIds()
  │    → query ObjectBox: serverWordId NOT NULL, sort by lastSeenAt|updatedAt DESC
  │      up to 1000 IDs
  │
  └── apiClient.syncCacheInventory(deviceId, serverWordIds, sessionToken)
       PUT /v1/user-word-cache
       body: { device_id, server_word_ids: [...], observed_at }

Backend PUT /v1/user-word-cache:
  → store.replaceCachedWordIds(deviceId, userId, wordIds, observedAt)
  → Lọc: chỉ giữ IDs tồn tại trong words table, cap 1000
  → Ghi vào user_cached_words (replaces toàn bộ)
  Response: { stored_count, unknown_server_word_ids }
```

**Mục đích**: Backend biết client đang giữ từ nào để tránh gửi trùng lặp khi chọn thẻ tiếp theo.

---

## 11. Luồng xác thực người dùng (Auth Flows)

### 11.1 Đăng ký (Register)

```
UI: LearningDrawer → onRegister → _showIdentityDialog(includeDisplayName=true)
  │
controller.register(identifier, password, displayName)
  IF isAuthInProgress: return
  _beginAuthAction()  → isAuthInProgress=true, clear messages, notifyListeners
  │
  repository.registerUser(identifier, password, displayName)
    ├── deviceId = getOrCreateDeviceId()
    └── apiClient.registerUser(identifier, password, displayName, deviceId)
         POST /v1/users/register
         body: { identifier, password, display_name, device_id }

Backend:
  requireRegistrationInput({ identifier, password })
    → normalize identifier (trim, lowercase)
    → password phải >= 8 chars
    → throw InvalidRegistrationInputError → 400
  store.registerUser(...)
    → createPasswordHash(password) = "scrypt:<salt>:<hash>"
    → INSERT users
    → ON CONFLICT identifier → throw DuplicateUserError → 409 { "error": "user_exists" }
    → createSessionToken() = "session_<random32bytes>"
    → INSERT user_sessions
    → return { user, sessionToken }
  Response 201: { user_id, identifier, display_name, session_token }

Mobile SUCCESS:
  ├── database.saveUserSession(session) → setSetting("user_session", JSON)
  ├── userSession = session
  ├── authSuccessMessage = "Registered as <name>."
  └── _endAuthAction() → notifyListeners → UI hiện SnackBar

Mobile FAIL:
  ├── Map error: 409/user_exists → "An account already exists..."
  │             401/invalid_credentials → "Email or password is incorrect..."
  │             400/bad_request → "The request was rejected..."
  │             network/timeout → "Check connection and try again."
  ├── userSession = previousSession
  ├── authErrorMessage = message
  └── _endAuthAction()
```

### 11.2 Đăng nhập (Sign In)

```
controller.signIn(identifier, password)
  repository.signInUser(identifier, password)
    ├── deviceId = getOrCreateDeviceId()
    └── apiClient.signIn(identifier, password, deviceId)
         POST /v1/users/sign-in

Backend:
  store.createUserSession(identifier, password, deviceId)
    → normalizeUserIdentifier → lookup users
    → verifyPassword(password, storedHash) — timing-safe compare
    → throw InvalidCredentialsError → 401 { "error": "invalid_credentials" }
    → createSessionToken() + INSERT user_sessions
  Response 200: { user_id, identifier, display_name, session_token }

Mobile: tương tự register, lưu session, update UI
```

### 11.3 Đăng xuất (Sign Out)

```
controller.signOut()
  repository.signOutUser()
    ├── database.loadUserSession()
    │    IF null: return (already signed out)
    ├── apiClient.signOut(session)
    │    POST /v1/users/sign-out (với Authorization: Bearer <token>)
    └── [finally] database.clearUserSession()  (luôn clear local, kể cả khi API fail)

Backend:
  bearerToken(request) → phải có
  store.revokeUserSession(sessionToken)
    → hashSessionToken(token) → DELETE/mark user_sessions
    → { revoked: true | false }
  Response: { success: true }

Mobile: userSession = null, authSuccessMessage = "Signed out.", notifyListeners
```

**Offline sign-out**: Nếu API call fail nhưng local session đã clear → thông báo "Signed out locally. Server sign-out could not be confirmed."

### 11.4 Session ảnh hưởng đến learning

Sau khi signed in, tất cả request gửi `Authorization: Bearer <token>`:
- `fetchProficiency`: lấy proficiency của user, không phải device
- `fetchLearningCards`: loại trừ từ user đã học
- `submitStudyEvent`: lưu event dưới user_id
- `syncStudyEvents`: associate với user
- `syncCacheInventory`: lưu dưới user_id

---

## 12. Luồng Proficiency — CEFR level tracking

### 12.1 CEFR Levels

`A1 → A2 → B1 → B2 → C1 → C2`

- **Tăng level** (`incrementLevel`): 5 lần liên tiếp rating `too_easy`
- **Giảm level** (`decrementLevel`): 5 lần liên tiếp rating `hard`
- **Reset counter**: khi rating type thay đổi (e.g., sau `easy`, sau `too_hard`)
- `isProgressionRating(rating)`: chỉ `too_easy` và `hard` tính là progression

### 12.2 Khởi tạo Proficiency

```
store.getOrInitializeProficiency(deviceId, userId, language)
  → Lookup user_proficiency:
      IF userId: WHERE user_id = userId AND language = lang
      ELSE: WHERE device_id = deviceId AND user_id IS NULL AND language = lang
  → IF not found:
      INSERT user_proficiency(device_id|user_id, language, level='A1')
      ON CONFLICT DO NOTHING (idempotent)
  → return current proficiency state
```

### 12.3 Tính consecutive rating

```
countConsecutiveRatings(deviceId|userId):
  → Query study_events cho owner, sort by occurred_at DESC
  → Đếm rating cùng type liên tiếp từ đầu (stop khi type thay đổi)
  → Chỉ `too_easy` (increment) và `hard` (decrement) tính

IF consecutive >= 5:
  → incrementLevel() hoặc decrementLevel()
  → UPDATE user_proficiency
  → level_changed = true, previous_level = old, triggered_by = "5x consecutive ..."
```

### 12.4 Mobile hiển thị level change

```
controller.rateCurrent()
  IF proficiency.levelChanged AND level != previousLevel:
    _levelChangeMessage = "Level changed: A1 -> A2"

LearningScreen._onControllerChanged():
  controller.takeLevelChangeMessage() → SnackBar
```

### 12.5 GET /v1/proficiency

```
Query params: device_id (required), language (optional, default "en")
resolveOptionalUserSession()

store.getProficiency(deviceId, userId, language)
  → Lookup theo userId nếu signed-in, deviceId nếu anonymous

Response: { device_id, user_id, level, level_changed, previous_level,
            triggered_by, consecutive_count, consecutive_rating_type,
            language, last_updated }
```

---

## 13. Luồng dự phòng offline (Offline Fallback)

| Tình huống | Hành vi |
|-----------|---------|
| `fetchLearningCards` fail khi `getNewWordWithFallbackResult` | Thử lấy từ `database.nextNewWord()` |
| Không có từ local | `statusMessage = "No backend or local new word was available."` |
| `submitStudyEvent` fail | Event vẫn ở `StudyEventEntity`, `SyncWorker` retry sau |
| `syncCacheInventory` fail sau gesture | Log warning, tiếp tục bình thường |
| `signOut` API fail | Clear local session bất kể, thông báo "signed out locally" |
| `fetchProficiency` fail khi startup | Dùng `ProficiencyState.initial()` (A1) |
| `syncPendingEvents` entry fail | `scheduleRetry()` với exponential backoff |

---

## 14. Logging & Telemetry

### 14.1 Backend Logging (JSON structured)

Mỗi request có `request_id` (từ `X-Request-Id` header hoặc random UUID).

**Log events chính**:
- `request_started` / `request_completed` (method, path, status, elapsed_ms)
- `request_failed` (category: validation_error | auth_error | internal_error | bad_request)
- `study_event_rejected` (invalid_rating)
- `scheduler_generation_started/completed/failed`
- `db_insert_word_completed`
- `session_resolution_failed`

**Redaction**: fields `token`, `password`, `secret`, `key` tự động redact trong log.

### 14.2 Mobile Logging (PersistedLogger → ObjectBox AppLogEntity)

**Categories**: `api`, `sync`, `session`, `auth`, `database`, `app`

**Log events chính**:
| Event | Category | Mô tả |
|-------|----------|-------|
| `new_word.local.hit` | api | Lấy được từ mới từ local |
| `new_word.refill.hit` | api | Từ mới sau khi refill backend |
| `new_word.refill.empty` | api | Refill không có từ nào |
| `new_word.backend.error` | api | Lỗi backend, dùng local fallback |
| `rating.easy.delete_local` | session | Từ easy bị xóa local |
| `rating.sync.success` | session | Rating sync thành công |
| `rating.sync.deferred` | sync | Rating queued for retry |
| `session.proficiency.changed` | session | Level thay đổi |
| `gesture.remembered.local_state_updated` | session | Swipe bottom→top |
| `gesture.difficult.local_state_updated` | session | Swipe top→down |
| `sync_worker.run_once.*` | sync | SyncWorker run |
| `auth.register.success` / `auth.sign_in.success` | auth | Auth thành công |
| `cache_inventory.sync` | sync | Cache sync |
| `learning_cards.refill` | api | Refill từ backend |
| `learning_cards.prefetch_batch` | api | Prefetch batch |
| `app.start` | app | App khởi động xong |

**Prune policy**: max 5000 entries, max 7 ngày.

### 14.3 TelemetrySink Events

| TelemetryEvent | Khi nào |
|----------------|---------|
| `newWordRequested` | `showNewWord()` |
| `newWordSwipeRequested` | Swipe right→left hoặc `showNewWord()` |
| `recentReviewSwipeRequested` | Swipe left→right |
| `newWordBackendSuccess` | Word từ backend refill |
| `newWordLocalFallback` | Word từ local cache |
| `newWordFallbackMiss` | Không có word nào |
| `cardShown` | Word hiển thị (new) |
| `reviewWordShown` | Word hiển thị (review) |
| `recentReviewHit` | Review word found |
| `recentReviewMiss` | Không có review word |
| `studyRatingSubmitted` | Rating được submit |
| `authRegisterSuccess/Failure` | Register kết quả |
| `authSignInSuccess/Failure` | Sign-in kết quả |
| `authSignOutSuccess/Failure` | Sign-out kết quả |

---

## 15. Database — Backend Schema (PostgreSQL)

### `words`
| Column | Type | Ghi chú |
|--------|------|---------|
| id | VARCHAR PK | prefix "word_" |
| term | VARCHAR | |
| normalized_term | VARCHAR | lowercase, whitespace normalized |
| language | VARCHAR | "en", "vi", ... |
| meaning_vi | TEXT | |
| part_of_speech | VARCHAR | |
| ipa | VARCHAR | |
| vietnamese_pronunciation | VARCHAR | |
| example | TEXT | |
| example_vi | TEXT | |
| difficulty | VARCHAR | CEFR: A1..C2 |
| topics_json | TEXT | JSON array |
| generation_source | VARCHAR | "seed", "litellm" |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**Unique constraint**: `(language, normalized_term)`

### `study_events`
| Column | Type | Ghi chú |
|--------|------|---------|
| id | VARCHAR PK | |
| client_event_id | VARCHAR UNIQUE | idempotency key |
| device_id | VARCHAR | |
| user_id | VARCHAR FK | nullable |
| server_word_id | VARCHAR FK | |
| local_word_id | VARCHAR | |
| rating | VARCHAR | easy/too_easy/hard/too_hard |
| language | VARCHAR | |
| occurred_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | |

### `user_proficiency`
| Column | Type | Ghi chú |
|--------|------|---------|
| id | VARCHAR PK | |
| device_id | VARCHAR | nullable khi user_id set |
| user_id | VARCHAR FK | nullable |
| language | VARCHAR | |
| level | VARCHAR | CEFR A1..C2 |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**Partial unique indexes**:
- `(device_id, language)` WHERE `user_id IS NULL`
- `(user_id, language)` WHERE `user_id IS NOT NULL`

### `user_cached_words` (advisory inventory)
| Column | Type | Ghi chú |
|--------|------|---------|
| id | SERIAL PK | |
| device_id | VARCHAR | |
| user_id | VARCHAR | nullable |
| word_id | VARCHAR FK | |
| observed_at | TIMESTAMPTZ | |

**Unique**: `(device_id, word_id)` hoặc `(user_id, word_id)` — idempotent upsert.

### `user_word_states` (latest state projection)
| Column | Type | Ghi chú |
|--------|------|---------|
| id | VARCHAR PK | |
| device_id | VARCHAR | |
| user_id | VARCHAR | nullable |
| word_id | VARCHAR FK | |
| last_rating | VARCHAR | |
| occurred_at | TIMESTAMPTZ | |

### `users`
| Column | Type | Ghi chú |
|--------|------|---------|
| id | VARCHAR PK | prefix "user_" |
| identifier | VARCHAR UNIQUE | normalized (lowercase email) |
| display_name | VARCHAR | nullable |
| password_hash | TEXT | "scrypt:<salt>:<hash>" |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

### `user_sessions`
| Column | Type | Ghi chú |
|--------|------|---------|
| id | VARCHAR PK | |
| user_id | VARCHAR FK | |
| token_hash | VARCHAR UNIQUE | sha256(session_token) |
| device_id | VARCHAR | |
| created_at | TIMESTAMPTZ | |
| revoked_at | TIMESTAMPTZ | nullable |

### `generation_runs`
| Column | Type | Ghi chú |
|--------|------|---------|
| id | VARCHAR PK | |
| target_language | VARCHAR | |
| mode | VARCHAR | "fill" / "daily_top_up" |
| status | VARCHAR | "success" / "failed" |
| requested_count | INT | |
| inserted_count | INT | |
| error_message | TEXT | nullable |
| run_date | DATE | YYYY-MM-DD |
| started_at | TIMESTAMPTZ | |
| finished_at | TIMESTAMPTZ | |

### `scheduler_locks`
| Column | Type | Ghi chú |
|--------|------|---------|
| target_language | VARCHAR PK | |
| owner_id | VARCHAR | |
| expires_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

## 16. Database — Mobile Local Store (ObjectBox)

**File**: `mobile/lib/src/data/local_database_entities.dart`

### `LocalWordEntity`

| Field | Type | Ghi chú |
|-------|------|---------|
| id | int | ObjectBox auto |
| localId | String | UUID |
| serverWordId | String? | từ backend |
| term | String | |
| language | String | |
| meaningVi | String | |
| partOfSpeech | String? | |
| ipa | String? | |
| vietnamesePronunciation | String? | |
| example | String? | |
| exampleVi | String? | |
| difficulty | String? | CEFR |
| topicsJson | String | JSON array |
| status | String | WordStatus enum name |
| lastSeenAtMs | int? | epoch ms |
| nextReviewAtMs | int? | epoch ms |
| createdAtMs | int | epoch ms |
| updatedAtMs | int | epoch ms |

**WordStatus enum**: `newWord`, `learning`, `review`, `mastered`

**1000-word cap**: `addBatch()` prune oldest non-pending words khi >= 990.

### `StudyEventEntity`

| Field | Type | Ghi chú |
|-------|------|---------|
| id | int | |
| clientEventId | String | UUID, idempotency |
| localWordId | String | |
| serverWordId | String? | |
| ratingValue | String | StudyRating.name |
| occurredAtMs | int | epoch ms |
| syncStatusValue | String | SyncStatus.name |

### `SyncQueueEntity`

| Field | Type | Ghi chú |
|-------|------|---------|
| id | int | |
| clientEventId | String | FK → StudyEvent |
| payload | String | JSON |
| attemptCount | int | |
| nextRetryAtMs | int | epoch ms |
| createdAtMs | int | |

### `AppSettingEntity`

| Field | Type | Ghi chú |
|-------|------|---------|
| id | int | |
| key | String | unique |
| value | String | |

**Built-in keys**:
- `device_id`
- `user_session` (JSON)
- `is_prefetch_done`
- `last_daily_refresh_date`
- `words_studied_since_last_refresh`

### `AppLogEntity`

| Field | Type | Ghi chú |
|-------|------|---------|
| id | int | |
| timestampMs | int | epoch ms |
| level | String | debug/info/warning/error |
| category | String | AppLogCategory.name |
| event | String | |
| message | String | |
| traceId | String? | |
| contextJson | String | JSON object |

---

## 17. Cấu hình môi trường

### Backend (`backend/src/config.js`)

| Biến | Default | Mô tả |
|------|---------|-------|
| `PORT` | 8787 | HTTP port |
| `DATABASE_URL` | - | PostgreSQL connection string |
| `LITELLM_BASE_URL` | https://lite.x51.vn | LiteLLM proxy URL |
| `LITELLM_API_KEY` | "" | API key cho LiteLLM |
| `LITELLM_MODEL` | gpt-4o-mini | Model |
| `DEFAULT_SOURCE_LANGUAGE` | vi | Ngôn ngữ nguồn (Vietnamese) |
| `DEFAULT_TARGET_LANGUAGE` | en | Ngôn ngữ học |
| `NEW_WORD_TIMEOUT_SECONDS` | 5 | Timeout gọi generation |
| `CORS_ALLOWED_ORIGIN` | * | Origin cho CORS |
| `APP_CREDENTIALS_JSON` | [] | JSON array `[{appId, secret, status}]` |
| `APP_CREDENTIAL_TIMESTAMP_SKEW_SECONDS` | 300 | Cho phép clock skew |
| `APP_CREDENTIAL_NONCE_TTL_SECONDS` | 300 | TTL chống replay |
| `LOG_LEVEL` | info | debug/info/warn/error |
| `LOG_REDACTION_ENABLED` | true | Redact sensitive fields |
| `VOCAB_SCHEDULER_ENABLED` | true | Bật/tắt scheduler |
| `VOCAB_POOL_MIN_SIZE` | 1000 | Pool tối thiểu trước khi chuyển sang daily |
| `VOCAB_FILL_INTERVAL_SECONDS` | 60 | Tần suất kiểm tra pool |
| `VOCAB_DAILY_GENERATION_COUNT` | 10 | Số từ sinh mỗi ngày (top-up) |
| `VOCAB_DAILY_GENERATION_HOUR_UTC` | 0 | Giờ UTC để chạy daily top-up |
| `VOCAB_GENERATION_BATCH_SIZE` | 20 | Số từ mỗi batch khi fill |
| `VOCAB_SCHEDULER_LOCK_TTL_SECONDS` | 120 | TTL lock scheduler |

### Mobile (`mobile/lib/src/config.dart`, `--dart-define`)

| Biến | Default | Mô tả |
|------|---------|-------|
| `BACKEND_BASE_URL` | http://localhost:8787 | Backend URL |
| `NEW_WORD_TIMEOUT_SECONDS` | 5 | HTTP timeout |
| `APP_CREDENTIAL_APP_ID` | app_mobile_dev | App ID |
| `APP_CREDENTIAL_SECRET` | dev-secret | Signing secret |
| `LOG_LEVEL` | info | Log level |
| `LOG_MAX_ENTRIES` | 5000 | Max log entries in DB |
| `LOG_RETENTION_DAYS` | 7 | Log retention |
| `VOCAB_PREFETCH_LIMIT` | 1000 | First-install prefetch limit |
| `VOCAB_PROACTIVE_THRESHOLD` | 100 | Số từ đã học để trigger proactive refill |
| `VOCAB_PROACTIVE_MIN_NEW` | 15 | Ngưỡng unstudied để trigger proactive refill |

---

*Document này được sinh tự động từ review codebase ngày 2026-05-06.*
