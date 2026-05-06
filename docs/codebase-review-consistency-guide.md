# Codebase Review & Consistency Guide

> Branch: `features/register-user`  
> Reviewed: 2026-05-06  
> Mode: Pre-change explore/review note. The `resolve-codebase-consistency-drift`
> implementation resolved the highest-priority issues listed here; keep this as
> historical review input, not current-state documentation.

## Scope

Review này nhìn theo hướng "giữ nhất quán giữa các project" trong cùng repo:

- `backend/`: Express API, in-memory store, PostgreSQL store, DB schema.
- `mobile/`: Flutter app, ObjectBox local cache, API client, learning session flow.
- `contracts/`: mobile/backend API contract.
- `openspec/`: active/completed change artifacts.
- `docs/`: setup, release notes, investigation docs.

## Source Of Truth Map

```text
OpenSpec accepted specs
        |
        v
contracts/api.md
        |
        v
backend/src/app.js  <->  backend/src/*_word_store.js
        |
        v
mobile/lib/src/api/backend_api_client.dart
        |
        v
mobile/lib/src/data/word_repository.dart
        |
        v
mobile/lib/src/session/learning_session_controller.dart
        |
        v
tests + README/docs/release notes
```

Nguyen tac chinh: moi thay doi API hoac data flow phai di qua ca chuoi tren. Neu mot field/endpoint/config chi ton tai o mot diem, no la dau hieu drift.

## Executive Summary

Repo dang o trang thai co nhieu thay doi chua commit va it nhat 2 active OpenSpec changes:

- `mobile-vocabulary-prefetch-refresh`: OpenSpec bao cao `0/30` tasks complete, nhung code da co `VocabularyRefreshWorker`, settings keys, tests va startup integration.
- `add-adaptive-proficiency-system`: OpenSpec bao cao `66/97` tasks complete, nhung mot so task/spec van noi ve `/v1/words/next`, trong khi contract hien tai da chon `/v1/learning/cards` la endpoint duy nhat.

Nhung inconsistency can uu tien:

1. `syncStudyEvents` co bug response shape khi sync batch rong hoac toan bo event bi reject.
2. API param contract dang drift: `card_mode`, `source_language`, `device_id`, `excludeIds`.
3. Mobile local-cache invariant "toi da 1000 tu" chua duoc enforce o moi path.
4. OpenSpec/docs van lan lon giua SQLite vs ObjectBox va `/v1/words/next` vs `/v1/learning/cards`.
5. App credential nonce tren mobile dung timestamp, khong random.

## Architecture Snapshot

```text
              signed /v1 request
Mobile API Client ------------------> Backend Express
       |                                  |
       |                                  v
       |                         app credential guard
       |                                  |
       v                                  v
WordRepository                   WordStore interface
       |                           /              \
       v                          v                v
LocalDatabase/ObjectBox     In-memory store    Postgres store
       |
       v
LearningSessionController
```

Consistency surface nguy hiem nhat la `WordStore` vs `PostgresWordStore`: tests thuong dung in-memory, production dung PostgreSQL. Hai implementation phai co cung method signature, cung validation semantics, va cung response shape.

## Findings

### P0 - `syncStudyEvents` tra `proficiency: undefined` khi khong co event nao duoc xu ly

**Files:**

- `backend/src/word_store.js`: lines 229-232 khoi tao `latestResult` bang `getProficiency()`, lines 258-262 tra `latestResult.proficiency`.
- `backend/src/postgres_word_store.js`: lines 373-377 khoi tao `latestResult` bang `getProficiency()`, lines 405-409 tra `latestResult.proficiency`.

**Van de:** `getProficiency()` tra ve proficiency object truc tiep. `recordStudyEvent()` moi tra object co property `.proficiency`. Neu `events: []` hoac tat ca events bi reject, `latestResult.proficiency` la `undefined`.

**Impact:** `POST /v1/study-events/sync` co the mat field `proficiency`, trong khi `contracts/api.md` document response luon co proficiency cho sync result.

**Consistency rule:** Moi store method phai co mot internal response model on dinh. Khong dung cung bien cho 2 shape khac nhau.

**Suggested direction:** Dung `latestProficiency` rieng:

```js
let latestProficiency = await this.getProficiency({ deviceId, userId, language });
// after accepted event:
latestProficiency = result.proficiency;
return { accepted_event_ids, rejected_events, proficiency: latestProficiency };
```

### P1 - `card_mode` duoc document/sent/passed nhung store khong validate hoac dung

**Files:**

- `contracts/api.md`: lines 180-186 document `card_mode: "new"`, lines 189-195 noi `new` la supported value.
- `mobile/lib/src/api/backend_api_client.dart`: lines 194-200 hardcode `card_mode: 'new'`.
- `backend/src/app.js`: lines 154-160 va 168-174 pass `cardMode` vao store.
- `backend/src/word_store.js`: line 196 signature khong nhan `cardMode`.
- `backend/src/postgres_word_store.js`: line 331 signature khong nhan `cardMode`.

**Van de:** Backend route normalize `card_mode`, nhung store bo qua. Neu client gui mode khac `new`, request van co the thanh cong va response van la new cards. Contract noi chi `new` supported, nhung implementation khong reject unsupported values.

**Decision can chot:** Chon 1 trong 2:

- Neu release nay chi co `new`: backend reject `card_mode` khac `new` voi `400 { "error": "bad_request" }`, va bo `cardMode` khoi store call.
- Neu `card_mode` la expansion point: them vao store signatures, tests cho unsupported mode, va document future modes ro rang.

### P1 - `/v1/words/recent` query params khong nhat quan giua mobile, contract va backend

**Files:**

- `contracts/api.md`: lines 239-245 document `limit`, `source_language`, `target_language`.
- `mobile/lib/src/api/backend_api_client.dart`: lines 123-135 gui `limit`, `source_language`, `target_language`, optional `device_id`.
- `mobile/lib/src/api/backend_api_client.dart`: lines 127, 149-152, 179-185 nhan/log/filter `excludeIds`, nhung khong gui len query string.
- `backend/src/app.js`: lines 190-195 chi doc `limit` va `target_language`.

**Van de:**

- `source_language` duoc mobile gui va contract document, nhung backend khong doc.
- `device_id` duoc mobile gui, nhung contract khong document va backend khong doc.
- `excludeIds` duoc worker truyen vao, API client log/filter client-side, nhung backend khong biet nen daily/proactive refresh co the tra it hon `limit` sau khi client filter duplicate.

**Impact:** Prefetch/refresh flow co ve co duplicate avoidance, nhung thuc te chi la best-effort client filter sau khi da tai batch. Khi local cache lon, daily refresh co the fetch 20/150 items nhung sau filter con rat it.

**Consistency rule:** Moi query param phai thuoc 1 trong 3 trang thai:

- `implemented`: mobile sends, contract documents, backend validates/uses, tests cover.
- `reserved`: contract noi ro reserved va backend ignores intentionally.
- `removed`: mobile khong gui, contract khong document.

### P1 - App credential nonce tren mobile la timestamp, khong random

**File:** `mobile/lib/src/api/backend_api_client.dart`: lines 440-459.

**Van de:** `nonce = 'mobile_${DateTime.now().microsecondsSinceEpoch}'` la sequential timestamp. Contract yeu cau nonce random 128-bit hoac lon hon. Neu 2 request tao nonce trong cung microsecond hoac clock behavior bat thuong, backend nonce cache co the reject nhu replay.

**Impact:** Runtime flake kho debug o startup/sync/refill khi co nhieu signed requests gan nhau.

**Suggested direction:** Dung UUID v4 hoac crypto-random bytes cho nonce. Repo da co dependency `uuid`.

### P1 - Local cache cap 1000 words chua duoc enforce o moi path

**Files:**

- `mobile/lib/src/data/local_database.dart`: lines 600-613 comment noi `addBatch` enforce 1000 cap, nhung code chi prune ve 990 neu count truoc khi insert >= 990.
- `mobile/lib/src/data/word_repository.dart`: lines 371-382 `refillLearningCards()` goi `database.addBatch()` va khong prune sau do.
- `mobile/lib/src/data/word_repository.dart`: lines 396-407 `prefetchBatch()` goi `database.addBatch()` va khong prune sau do.
- `mobile/lib/src/data/vocabulary_refresh_worker.dart`: lines 31-39, 69-78, 106-114 co prune sau manual upsert.

**Van de:** Neu count hien tai la 950 va batch la 100, `addBatch()` se ket thuc o 1050. Neu count la 990 va batch la 100, prune ve 990 roi insert 100 -> 1090. Test hien tai chi cover batch 10 tai count 995, nen khong bat case batch lon.

**Impact:** Trai voi OpenSpec `mobile-local-cache-sync` yeu cau local store giu <= 1000 words. Cache inventory sync cung co the gui nhieu hon ky vong neu local DB vuot cap.

**Consistency rule:** Invariant cap phai nam trong API duy nhat (`addBatch` hoac transaction local DB), khong phu thuoc caller nho goi prune.

### P1 - Postgres `user_proficiency` dang dung synthetic `device_id` cho user records

**Files:**

- `backend/db/schema.sql`: lines 52-62 `user_proficiency` chi unique theo `(device_id, language)`.
- `backend/src/postgres_word_store.js`: lines 650-660 query theo `user_id`, nhung insert `device_id = user:${userId}`.
- `backend/src/postgres_word_store.js`: lines 671-683 conflict theo `(device_id, language)`.

**Van de:** User-level proficiency duoc luu bang convention `device_id = "user:<id>"` de an khop unique constraint. Schema da co `user_id`, nhung khong co unique partial index cho `(user_id, language)`.

**Impact:** Data model kho reason khi can migrate/merge anonymous device state voi signed-in user state. Query code phai biet convention an trong nay.

**Suggested direction:** Them unique partial index rieng cho user records va insert/update bang `user_id`.

```sql
CREATE UNIQUE INDEX idx_user_proficiency_user_language_unique
ON user_proficiency(user_id, language)
WHERE user_id IS NOT NULL;
```

### P2 - Prefetch/refresh defaults drift giua proposal, tasks, config va runtime

**Files:**

- `openspec/changes/mobile-vocabulary-prefetch-refresh/proposal.md`: lines 3, 7-11 noi prefetch 1000, daily 150, proactive 15/100.
- `openspec/changes/mobile-vocabulary-prefetch-refresh/tasks.md`: lines 39-42 noi config defaults `1000`, `150`, `100`, `15`.
- `mobile/lib/src/config.dart`: lines 45-59 default hien tai la `10`, `10`, `100`, `10`.
- `mobile/lib/main.dart`: lines 49-56 co synchronous prefetch neu local count < 10, roi moi fire-and-forget checks.
- `contracts/api.md`: line 194 noi `/v1/learning/cards.limit` capped at `10`, trong khi backend route clamp toi `100` o `backend/src/app.js` line 152.

**Van de:** Cung mot concept "prefetch" dang co it nhat 4 so khac nhau: 10, 100, 150, 1000. Proposal noi non-blocking, code startup co path await `prefetchBatch()`.

**Impact:** Kho biet expected product behavior la "bootstrap 1000 words", "top up 100 words", hay "load 10 words". Tests co the pass theo config test rieng nhung production default khac intent.

**Decision can chot:** Chon mot cap/strategy:

- `POST /v1/learning/cards` batch cap 100 va mobile lap nhieu batch de dat 1000, hoac
- `/v1/words/recent` la bootstrap 1000 va `/v1/learning/cards` chi la top-up 10/100, hoac
- San pham MVP chi can 10/100, thi update proposal/tasks de bo 1000/150.

### P2 - Active OpenSpec artifacts stale so voi code hien tai

**Files:**

- `openspec/changes/mobile-vocabulary-prefetch-refresh/tasks.md`: lines 1-50 tat ca unchecked, nhung code da co settings, worker, API client, repository, startup, va tests.
- `openspec/changes/mobile-vocabulary-prefetch-refresh/design.md`: lines 8-12 van mo ta SQLite/sqflite va `/v1/words/next`.
- `openspec/changes/add-adaptive-proficiency-system/tasks.md`: lines 77-85 va 144-165 mark `/v1/words/next` work as done/documented.
- `openspec/changes/unify-learning-cards-backend-state/tasks.md`: lines 1-7, 20-23, 30-40 da complete viec remove `/v1/words/next` va dung `/v1/learning/cards`.

**Van de:** OpenSpec khong con la reliable map cua reality. Co completed change moi hon da thay doi API direction, nhung active adaptive change van noi route cu la done.

**Impact:** Agent hoac dev tiep theo co the implement nguoc lai route cu, hoac tick tasks sai.

**Suggested direction:** Lam mot pass "OpenSpec reconciliation":

- Update `mobile-vocabulary-prefetch-refresh/tasks.md` status theo code that.
- Update `mobile-vocabulary-prefetch-refresh/design.md` tu SQLite -> ObjectBox va `/v1/words/next` -> `/v1/learning/cards`/`/v1/words/recent`.
- Mark `add-adaptive-proficiency-system` tasks lien quan `/v1/words/next` la superseded, hoac rewrite sang `/v1/learning/cards`.
- Archive completed changes de active list chi con work thuc su dang mo.

### P2 - Docs drift: mobile README va setup docs van noi boilerplate/SQLite

**Files:**

- `mobile/README.md`: lines 1-16 van la Flutter boilerplate.
- `docs/mvp-setup.md`: lines 9-10 va 127-143 van noi SQLite/sqflite.
- `docs/mvp-setup.md`: lines 149-152 noi `GET /v1/learning/cards` va 15/85 mix, trong khi contract hien tai la `POST /v1/learning/cards` va `card_mode: new`.
- `docs/release-notes.md`: lines 3-29 co ObjectBox release notes dung hon setup docs.

**Van de:** Source docs cho dev setup va release docs khong cung state.

**Impact:** Dev moi co the cai SQLite dependencies khong can thiet, goi sai HTTP method, hoac hieu sai card mix.

**Suggested direction:** Danh dau docs theo loai:

- `contracts/api.md`: API source of truth.
- `docs/mvp-setup.md`: current runnable setup only.
- `docs/20*.md`: dated investigation, not source of truth.
- `docs/release-notes.md`: user/developer release delta.

### P2 - Log semantics trong new-word flow chua khop voi thuc te

**File:** `mobile/lib/src/data/word_repository.dart`: lines 233-257.

**Van de:** Khi local word ton tai sau backend-managed refill/cache, log event la `new_word.backend.success`, message noi selected from backend refill cache. Neu `usedBackendRefill == false`, source return la local fallback nhung event name van co `backend.success`. Khi backend returned no new words, `fallback_hit: localWord != null` luon false vi branch nay chi chay sau khi `localWord == null`.

**Impact:** Telemetry/debugging bi nhieu. Khi review incident offline/cache, log event khong phan biet local hit, refill hit, va miss.

**Suggested direction:** Tach event names:

- `new_word.local.hit`
- `learning_cards.refill.success`
- `new_word.local.miss`
- `new_word.refill.empty`

### P3 - Historical docs contain obsolete routes/storage without clear "historical" label

Search shows many dated docs still mention `/v1/words/next` va SQLite. Dated investigation docs can giu lai, nhung can frontmatter hoac note ro "historical, not source of truth". Neu khong, search results se lam dev doc discovery bi sai.

## Consistency Rules To Maintain

### Rule 1 - API parameter lifecycle

Moi API field/query/header phai co checklist:

- [ ] Contract documents it.
- [ ] Backend reads, validates, or explicitly ignores as reserved.
- [ ] Mobile sends it only if backend supports it.
- [ ] Tests cover accepted and rejected values.
- [ ] Docs mention it only in current setup docs if it is live.

### Rule 2 - Store parity

`WordStore` va `PostgresWordStore` phai co cung:

- Method names and parameter names.
- Return object shapes.
- Idempotency behavior.
- Validation errors.
- Limit/cap behavior.

Moi khi sua mot store, them/doi test phai fail tren ca in-memory va Postgres integration path.

### Rule 3 - Contracts before clients

`contracts/api.md` phai la source of truth cho mobile/backend. Neu code khac contract, hoac code sai, hoac contract da stale. Khong de "implementation knows better" trong thoi gian dai.

### Rule 4 - Local cache invariants live in LocalDatabase

Invariant nhu "toi da 1000 words" khong nen phu thuoc caller. `LocalDatabase.addBatch()` hoac transaction tuong duong phai enforce cap sau moi write path.

### Rule 5 - OpenSpec lifecycle hygiene

Active change chi nen chua decision/task con dang mo. Neu mot change da complete:

- Archive no.
- Hoac update status/tasks ngay khi code da co.
- Neu change moi supersede route/design cu, ghi "superseded by <change>" vao artifact cu.

### Rule 6 - Current docs vs historical docs

Docs co ngay thang/investigation duoc phep stale, nhung can label. Docs khong co ngay thang nhu `README.md`, `mobile/README.md`, `docs/mvp-setup.md`, `contracts/api.md` phai reflect current runnable system.

## Recommended Cleanup Queue

```text
1. Fix syncStudyEvents response shape in both stores.
2. Decide card_mode semantics, then enforce or remove.
3. Reconcile /v1/words/recent params: source_language, device_id, excludeIds.
4. Replace timestamp nonce with random nonce.
5. Enforce local 1000-word cap inside LocalDatabase.addBatch.
6. Reconcile OpenSpec active changes with current code.
7. Update mobile README and docs/mvp-setup for ObjectBox + POST /v1/learning/cards.
8. Mark dated historical docs as historical where they mention old routes/storage.
```

## Test Gaps

| Area | Gap |
|------|-----|
| `syncStudyEvents` empty batch | Assert proficiency is present for `events: []`. |
| `syncStudyEvents` all rejected | Assert current proficiency is still returned. |
| `card_mode` unsupported | Assert backend rejects or handles according to contract. |
| `/v1/words/recent` params | Assert only supported params are sent/read; test `excludeIds` behavior. |
| Nonce generation | Assert nonce format/uniqueness is random enough for concurrent requests. |
| `addBatch` cap | Test count 950 + batch 100 and count 990 + batch 100. |
| OpenSpec reconciliation | Validate active changes do not reference removed endpoint `/v1/words/next` unless marked superseded. |

## Final Notes

The core architecture direction is clear: backend-owned batch selection through `POST /v1/learning/cards`, ObjectBox-only mobile persistence, signed `/v1/*` requests, and optional user sessions layered on app credentials. The main consistency work is not inventing new architecture. It is deleting stale forks of the old one and making the live contract unambiguous.
