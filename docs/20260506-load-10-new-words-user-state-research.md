# Research: Load 10 New Words With Backend-Owned User State

> Historical note (2026-05-06): this explore-mode research intentionally
> records intermediate findings. Current behavior is `POST /v1/learning/cards`
> with backend-owned duplicate avoidance and ObjectBox local storage; use
> `contracts/api.md` for the live API contract.

Ngay 2026-05-06. Tai lieu nay la ket qua explore mode: chi nghien cuu codebase va de xuat huong thiet ke, chua implement.

## Yeu Cau Dang Xet

1. Moi lan mobile can load tu moi, backend tra ve 10 tu moi trong mot batch.
2. Backend luu thong tin cac tu va trang thai hoc tu cua tung learner.
3. Neu user chua dang nhap, mobile dung mot anonymous id on dinh, duoc dong bo voi backend.
4. Khi backend da biet state cua learner, request load tu moi khong can gui `word_id` / exclude word ids nua.
5. Loai bo hoan toan duong cu `/v1/words/next`; khong can backward compatibility.
6. Chi dung mot duong duy nhat cho card loading: `/v1/learning/cards`.

## OpenSpec Context

`openspec list --json` dang co hai change lien quan truc tiep:

- `mobile-vocabulary-prefetch-refresh`: in-progress, huong cu la mobile prefetch/refresh local cache.
- `backend-managed-vocabulary-pool-selection`: complete, huong moi la backend chon card dua tren database state, cache inventory, va study events.

Code hien tai da nghieng ve backend-managed flow hon la proposal mobile prefetch ban dau.

## Hien Trang Codebase

### Backend endpoints

- `GET /v1/words/next` o `backend/src/app.js:137`: endpoint cu can xoa, co `limit` cap 20, nhan `device_id`, bearer session optional, va van nhan repeated `exclude_server_word_id`.
- `GET /v1/learning/cards` o `backend/src/app.js:166`: endpoint batch, `limit` cap 50, yeu cau `device_id`, dung `store.learningCards()`, tra `card_type` va `selection_reason`.
- `GET /v1/words/recent` o `backend/src/app.js:198`: tra recent words, cap 1000, khong dung user state.
- `POST /v1/study-events` va `/v1/study-events/sync` o `backend/src/app.js:208`: ghi study events va update state.
- `PUT /v1/user-word-cache` o `backend/src/app.js:286`: mobile report local cache inventory de backend tranh duplicate.

### Backend data model

Schema hien co o `backend/db/schema.sql`:

| Table | Vai tro |
| --- | --- |
| `words` | Vocabulary master data. |
| `study_events` | Event log append-only cho moi lan user rate tu. |
| `user_word_states` | Projection state moi nhat cua tung word theo `user_id` hoac anonymous `device_id`. |
| `user_cached_words` | Inventory cac `word_id` dang nam trong local cache cua device/user. |
| `user_proficiency` | CEFR/proficiency state theo user/device. |
| `users`, `user_sessions` | Signed-in identity. |

`PostgresWordStore.recordStudyEvent()` insert `study_events`, sau do goi `#upsertWordState()` de ghi `user_word_states` (`backend/src/postgres_word_store.js:426`, `backend/src/postgres_word_store.js:809`). Status hien tai:

```text
easy / too_easy -> completed
too_hard       -> learning
hard           -> review
```

`learningCards()` hien dang exclude cac word da cached va cac word da co state, roi chon mix 15% new / 85% review (`backend/src/postgres_word_store.js:331`).

### Mobile identity va local state

Mobile dang tao stable id bang UUID v4 va luu trong `app_settings.key = device_id` (`mobile/lib/src/data/local_database.dart:321`). `WordRepository.getOrCreateDeviceId()` goi logic nay (`mobile/lib/src/data/word_repository.dart:35`).

Local SQLite hien co:

- `local_words`: cache word + local status.
- `study_events`: pending/synced study event.
- `sync_queue`: retry queue.
- `app_settings`: device id, user session, prefetch/refresh flags.

### Mobile word loading flow hien tai

`LearningSessionController.showNewWord()` van lay `currentWord?.serverWordId` lam exclude id, roi goi `WordRepository.getNewWordWithFallbackResult()` (`mobile/lib/src/session/learning_session_controller.dart:82`).

Trong repository:

1. Neu local unstudied count thap, goi `refillLearningCards(limit: vocabProactiveMinNew)` (`mobile/lib/src/data/word_repository.dart:213`).
2. Sau do van lay `recentServerWordIds()` va gui `excludeServerWordIds` vao `/v1/words/next` voi `limit: 1` (`mobile/lib/src/data/word_repository.dart:231`).
3. `refillLearningCards()` goi `/v1/learning/cards`, upsert local words, prune, roi sync cache inventory (`mobile/lib/src/data/word_repository.dart:371`).

Day la diem chua khop voi yeu cau moi: path cu van gui word ids trong request, chi fetch 1 word, va can bi loai bo thay vi giu compatibility.

## So Do Hien Tai

```text
                       optional bearer session
                              │
                              ▼
Mobile ── device_id ──▶ Backend identity resolver
  │                           │
  │                           ├─ signed in: user_id + device_id context
  │                           └─ anonymous: device_id where user_id IS NULL
  │
  ├─ GET /v1/learning/cards?limit=N
  │       target path, uses user/cache state, but currently returns new/review mix
  │
  └─ PUT /v1/user-word-cache
          reports active local cache inventory
```

## Khoang Cach So Voi Yeu Cau

1. `GET /v1/words/next` dang la per-word flow trong mobile (`limit: 1`) va request co exclude ids.
2. `GET /v1/learning/cards` da co backend state, nhung contract la mixed learning cards, khong phai "10 tu moi".
3. Backend co `user_word_states`, nhung chi ghi sau khi co study event. Tu da "duoc backend tra ve nhung chua hoc" hien duoc theo doi bang `user_cached_words`, phu thuoc mobile sync cache inventory.
4. Anonymous identity hien goi la `device_id` va la raw UUID. Chua co convention `anonymous_<uuid>`.
5. Signed-in selection hien co nguy co bo qua lich su anonymous truoc do, vi query signed-in state thuong dung `user_id` thay vi union voi old anonymous `device_id`.
6. Contract can duoc lam sach thanh mot duong `/v1/learning/cards`; khong giu fallback `/v1/words/next`.

## De Xuat Anonymous Id

De xuat dung format:

```text
anonymous_<uuid-v4>
```

Vi du:

```text
anonymous_0a7b6a2e-0b24-4cbb-85bb-b49e1f6f2d72
```

Ly do:

- Phu hop style id hien co cua backend (`word_<uuid>`, `user_<uuid>`, `session_...`).
- Khong chua PII.
- De nhan dien trong log, dashboard, va DB.
- Khong tiep tuc coi raw UUID la public contract. Voi huong lam sach khong backward compatibility, mobile nen tao/luu id theo format `anonymous_<uuid-v4>`; neu gap local raw UUID cu thi proposal implementation co the normalize sang prefix nay hoac reset anonymous id theo chinh sach rollout.

Khuyen nghi giai doan 1: tiep tuc gui gia tri nay qua field/API param `device_id`, vi codebase hien da dung `device_id` lam anonymous owner key. Document lai y nghia: khi chua dang nhap, `device_id` la anonymous learner id va phai co prefix `anonymous_`; khi da dang nhap, bearer token quyet dinh `user_id`, con `device_id` van la local cache/device context.

Khong nen tao bang anonymous user rieng ngay lap tuc neu muc tieu chi la selection/state. Cac bang hien tai da support anonymous qua `device_id` + `user_id IS NULL`.

## De Xuat API Cho "Load 10 Tu Moi"

Quyet dinh moi: khong sua `/v1/words/next` va khong tao them `/v1/learning/new-words`. Duong duy nhat cho card loading la `/v1/learning/cards`.

Vi backend can ghi nhan batch da cap/da cache de request tiep theo khong can gui word ids, contract sach nhat la dung cung path `/v1/learning/cards` voi semantics claim batch. Neu proposal implementation muon giu method `GET` de it churn hon thi van chi duoc giu path nay; tuy nhien `POST` phu hop hon neu endpoint co side effect persist claim.

Request de xuat:

```http
POST /v1/learning/cards
Content-Type: application/json

{
  "device_id": "anonymous_<uuid>",
  "target_language": "en",
  "limit": 10,
  "card_mode": "new"
}
```

Signed-in request them:

```http
Authorization: Bearer <session_token>
```

Response:

```json
{
  "items": [
    {
      "server_word_id": "word_123",
      "term": "reliable",
      "language": "en",
      "meaning_vi": "dang tin cay",
      "difficulty": "B1",
      "card_type": "new",
      "selection_reason": "new_available"
    }
  ],
  "requested_count": 10,
  "actual_count": 10,
  "owner": {
    "kind": "anonymous",
    "id": "anonymous_<uuid>"
  }
}
```

Khuyen nghi: dung `POST` tren path `/v1/learning/cards`. Ly do la "tra ve 10 tu moi va backend ghi nhan da cap/da cache" la mot thao tac co side effect. POST ro rang hon GET, va giup backend dam bao request tiep theo khong can gui word ids ma van tranh duplicate.

Trong proposal moi, bo dong `card_mode` neu san pham quyet dinh `/v1/learning/cards` mac dinh la load 10 new cards. Neu van can review cards trong tuong lai, `card_mode` giup giu mot duong duy nhat ma khong mo them endpoint.

Cleanup bat buoc:

- Xoa route backend `/v1/words/next`.
- Xoa mobile client method `fetchNewWords()` neu chi con dung cho `/v1/words/next`.
- Xoa logic mobile build `excludeServerWordIds` va `excludeServerWordId`.
- Cap nhat `contracts/api.md` de chi document `/v1/learning/cards`.
- Sua/xoa tests dang assert `/v1/words/next`.
- Khong tao fallback compatibility.

## Backend Selection Flow De Xuat

```text
POST /v1/learning/cards
        │
        ▼
Resolve owner
  ├─ bearer hop le -> owner = user_id, device_id = cache context
  └─ khong bearer -> owner = anonymous device_id
        │
        ▼
Build exclusion set
  ├─ user_word_states: learned/review/learning/completed cua owner
  ├─ study_events fallback neu projection thieu
  └─ user_cached_words: word dang active trong local cache / da backend claim
        │
        ▼
Select 10 words tu `words`
  ├─ language/proficiency filter neu can
  ├─ exclude learned + cached + assigned
  └─ order theo generated/recent/chon logic san co
        │
        ▼
Persist claim
  └─ upsert returned word ids vao `user_cached_words`
        │
        ▼
Return 10 new words
```

Diem quan trong: neu request khong gui word ids nua, backend phai co mot trong hai co che:

1. Mobile sync cache inventory ngay sau khi nhan batch.
2. Backend tu ghi nhan batch da cap truoc khi return response.

Co che 2 on dinh hon vi lan goi tiep theo khong phu thuoc vao viec mobile da kip sync hay chua. `user_cached_words` co the lam bang "active assigned/cache inventory" trong giai doan nay.

## State Model De Xuat

```text
                    backend returns batch
┌────────────┐     and records cache claim      ┌──────────────┐
│ unassigned │ ───────────────────────────────▶ │ cached/new   │
└────────────┘                                  │ user_cached  │
                                                └──────┬───────┘
                                                       │ user rates
                                                       ▼
                                                ┌──────────────┐
                                                │ study_events │
                                                └──────┬───────┘
                                                       │ projection
                                                       ▼
                      ┌──────────────┬──────────────┬──────────────┐
                      │ learning     │ review       │ completed    │
                      │ too_hard     │ hard         │ easy/too_easy│
                      └──────────────┴──────────────┴──────────────┘
                                   user_word_states
```

Khuyen nghi khong tao `user_word_states.status = new` ngay trong phase dau, vi `learningCards()` hien coi moi state khac `completed` va `next_review_at <= now/null` la review candidate. Neu them state `new` ma khong sua selector, word vua duoc assigned co the bi xem nhu review.

Phase dau nen:

- `user_cached_words`: theo doi word da cap/active local cache.
- `user_word_states`: theo doi state sau khi user hoc/rate.
- `study_events`: event log nguon su that.

Neu sau nay muon state "assigned/new" trong `user_word_states`, can sua selector de chi `learning/review/mastered` moi la review candidates, con `assigned/new` chi dung de exclude khoi new selection.

## Data Model Gaps Can Luu Y Khi Proposal

1. `user_cached_words` hien chua co unique index theo owner + word. Neu backend se upsert claim, nen them unique indexes:

```sql
CREATE UNIQUE INDEX idx_user_cached_words_device_word
ON user_cached_words(device_id, word_id)
WHERE user_id IS NULL;

CREATE UNIQUE INDEX idx_user_cached_words_user_word
ON user_cached_words(user_id, word_id)
WHERE user_id IS NOT NULL;
```

2. `replaceCachedWordIds()` hien la full replace inventory. Neu backend cung ghi claim vao `user_cached_words`, can co method rieng dang additive upsert, vi new batch claim khong nen xoa toan bo inventory.

3. Signed-in merge: khi user dang nhap sau mot thoi gian hoc anonymous, backend nen:
   - hoac copy/merge anonymous `user_word_states` sang `user_id` khi register/sign-in;
   - hoac selection query signed-in exclusion bang union `user_id` + anonymous `device_id`.

Neu khong, user co the gap lai tu da hoc truoc khi dang nhap.

4. `GET /v1/words/recent` khong nen la API cho yeu cau nay, vi no khong doc user state va khong tranh duplicate theo learner.

## Mobile Flow De Xuat

```text
First run
  └─ getOrCreateDeviceId()
       └─ new install: anonymous_<uuid-v4>
       └─ existing raw UUID: normalize/reset, khong coi raw UUID la contract moi

Need new words
  └─ POST /v1/learning/cards { device_id, limit: 10, card_mode: "new" }
       └─ no exclude_server_word_id
       └─ no current word id
       └─ optional bearer token if signed in

After response
  ├─ upsert 10 words into local_words
  ├─ show one from local queue
  └─ optional cache inventory sync as reconciliation, not as primary duplicate guard

After rating
  ├─ insert local study_event
  ├─ POST /v1/study-events or queued sync
  ├─ backend upserts user_word_states
  └─ if easy/completed, mobile deletes local word and syncs cache inventory
```

`WordRepository.getNewWordWithFallbackResult()` nen ngung build `excludeServerWordIds` cho flow moi. Khong giu fallback `/v1/words/next`; neu backend batch fail thi mobile chi fallback local cache/offline queue.

## De Xuat Contract Tom Tat

### Canonical endpoint

```http
POST /v1/learning/cards
```

Body:

```json
{
  "device_id": "anonymous_<uuid>",
  "target_language": "en",
  "limit": 10,
  "card_mode": "new"
}
```

Rules:

- `limit` default 10, max 10 cho endpoint nay.
- Backend co gang tra dung 10 tu moi neu inventory du.
- Neu inventory khong du, tra it hon va log/metadata `actual_count`.
- Khong nhan `exclude_server_word_id`.
- Khong goi AI generation trong request path; chi doc pool DB.
- Neu co bearer session hop le, selection owner la `user_id`; van dung `device_id` cho local cache context.
- Neu khong co bearer, selection owner la anonymous `device_id`.

### Backend state rules

- New selection exclude:
  - words da co trong `user_word_states` cua owner;
  - words dang co trong `user_cached_words` cua owner/device;
  - words da co trong `study_events` neu projection thieu.
- Sau khi chon batch, backend upsert returned ids vao `user_cached_words`.
- Sau study event, backend upsert `user_word_states`.
- Cache inventory sync tu mobile van ton tai de reconcile khi local prune/delete.

## Rui Ro Va Trade-off

| Van de | Rui ro | Huong giam rui ro |
| --- | --- | --- |
| POST claim co side effect | Client request fail sau khi backend da claim, word bi "giu cho" nhung mobile khong co | Chap nhan vi batch nho; co the them `claimed_at`/TTL sau nay neu can. |
| Dung `user_cached_words` cho claim + cache | Ten bang hoi hep theo "cache inventory" hon la "assigned inventory" | Document lai semantics, hoac sau nay doi thanh `user_word_inventory`. |
| Signed-in sau anonymous | Neu khong merge se gap lai tu da hoc | Implement union exclusion hoac merge on login trong proposal. |
| Xoa `/v1/words/next` | Client cu se break | Chap nhan theo quyet dinh moi: khong backward compatibility; deploy backend/mobile cung nhip. |
| Always 10 new words | Pool co the khong du 10 sau khi exclude | Response can co `actual_count`; scheduler/pool monitor can top up. |

## Ket Luan De Xuat

Huong phu hop nhat voi quyet dinh moi la lam sach ve mot backend-owned batch claim endpoint duy nhat cho card loading:

```text
POST /v1/learning/cards
```

Endpoint nay resolve signed-in/anonymous owner, chon 10 tu moi dua tren `user_word_states` + `user_cached_words`, ghi nhan batch da cap vao backend, roi return items. Mobile se khong gui `word_id` hay exclude ids nua; no chi gui stable `device_id` dang format `anonymous_<uuid-v4>` neu chua dang nhap, va bearer token neu da dang nhap.

Day la thay doi nho hon so voi viec viet lai toan bo adaptive learning, vi tan dung duoc cac bang va services da co. Phan can lam ro trong proposal tiep theo la: chon strategy merge anonymous state khi user dang nhap va scope rollout khi xoa route cu. `/v1/words/next` khong con nam trong scope giu lai.
