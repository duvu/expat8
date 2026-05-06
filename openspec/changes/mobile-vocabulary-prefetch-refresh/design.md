## Context

> Current-state note (2026-05-06): this design predates the ObjectBox reset and
> backend-owned card selection. The live architecture uses ObjectBox-backed
> `LocalDatabase`, `POST /v1/learning/cards` for refill/top-up, and
> `PUT /v1/user-word-cache` for duplicate-avoidance inventory. `/v1/words/next`
> has been removed. The sections below are retained as historical design
> context and should not be implemented literally.

App hiện tại lấy từ mới theo cơ chế **on-demand**: mỗi khi người dùng cần từ mới, `WordRepository.nextNewWord()` truy vấn local DB; nếu không có, gọi backend `/v1/words/next`. Cơ chế này hoạt động nhưng có hai vấn đề:

1. **Trải nghiệm phụ thuộc mạng**: Người dùng mới cài chưa có từ nào trong local DB → mỗi từ đầu tiên đều phải chờ backend.
2. **Từ vựng không được làm mới tự động**: Local store chỉ tích luỹ từ đã học, không chủ động nạp từ mới. Người dùng có thể học hết từ trong local store mà không có từ mới sẵn sàng.

**Kiến trúc hiện tại:**
- `LocalDatabase` — SQLite qua sqflite, DB version 3, bảng `local_words` (max 1000 via `pruneToMostRecent`)
- `WordRepository` — lấy từ mới từ local hoặc fallback backend on-demand
- `SyncWorker` — chạy background, chỉ lo sync study events lên backend
- Backend có endpoint `/v1/words/recent?limit=1000` (bootstrap) và `/v1/words/next` (per-word)

## Goals / Non-Goals

**Goals:**
- Tải trước (prefetch) tối đa 1000 từ khi cài đặt lần đầu, background, không block UI
- Duy trì local store luôn có đủ từ mới chưa học: sau mỗi 100 từ người dùng học, phải có ≥15 từ mới sẵn sàng
- Refresh tự động 15%/ngày (~150 từ/ngày với store đầy 1000) qua background worker
- Local store luôn ≤ 1000 từ (loại bỏ từ cũ nhất đã học khi cần)
- Người dùng không bao giờ thấy latency mạng khi học từ mới

**Non-Goals:**
- Personalisation theo user level (nằm ngoài scope này)
- Sync prefetch state lên server
- Thay đổi backend API (chỉ dùng endpoints đã có)
- Prefetch cho review words (review đã có sẵn trong local)

## Decisions

### D1: Dùng `VocabularyRefreshWorker` tách biệt, không mở rộng `SyncWorker`

`SyncWorker` hiện chịu trách nhiệm sync study events. Thêm prefetch logic vào đây vi phạm Single Responsibility. Tạo `VocabularyRefreshWorker` riêng để:
- Prefetch batch khi first install (`isFirstInstall` flag trong `app_settings`)
- Refresh trigger định kỳ và proactive

**Thay thế đã cân nhắc:** Mở rộng `SyncWorker` — bị loại vì làm phức tạp class đang đơn giản.

### D2: Superseded — prefetch/refill now uses `POST /v1/learning/cards`

Current implementation uses backend-selected learning-card batches and cache
inventory for first-install prefetch, daily refresh, proactive refresh, and
on-demand refill. `/v1/words/recent` remains read-only bootstrap/diagnostic
support and does not accept learner-specific exclusions.

**Thay thế đã cân nhắc:** Tạo endpoint bulk riêng — không cần thiết khi endpoint hiện tại đáp ứng đủ.

### D3: Refresh trigger proactive dựa trên "words studied" counter

Sau mỗi lần người dùng rate một từ (`rateCurrent`), tăng counter `words_studied_since_last_refresh` trong `app_settings`. Khi counter ≥ 100 và số từ mới chưa học < 15, trigger `VocabularyRefreshWorker` để fetch thêm từ.

Tỷ lệ 15:100 nghĩa là cứ học 100 từ thì cần bổ sung 15 từ mới → đảm bảo luôn có từ mới sẵn sàng.

**Thay thế đã cân nhắc:** Timer-based refresh mỗi giờ — không responsive với hành vi thực tế của người dùng.

### D4: Daily refresh = thay thế 15% = ~150 từ/ngày với lưu timestamp trong `app_settings`

Lưu `last_daily_refresh_date` (ISO date string) trong bảng `app_settings`. Khi app khởi động, kiểm tra nếu ngày hiện tại ≠ `last_daily_refresh_date` thì trigger daily refresh:
- Fetch 150 từ mới từ backend (loại trừ `server_word_id` đã có trong local)
- Upsert vào local DB, gọi `pruneToMostRecent(maxWords: 1000)`
- Update `last_daily_refresh_date`

### D5: Superseded — duplicate avoidance is backend-owned

Mobile syncs active local `server_word_id` inventory to
`PUT /v1/user-word-cache`. Card selection and duplicate avoidance happen in
the backend on `POST /v1/learning/cards`; mobile does not send exclusion lists
for refill/top-up.

## Risks / Trade-offs

- **[Risk] Prefetch 1000 từ ngay khi install gây tốn băng thông** → Mitigation: Chỉ chạy một lần (guard bằng `is_prefetch_done` flag trong `app_settings`); batch request thay vì 1000 individual calls.
- **[Risk] Daily refresh fetch từ trùng với local** → Mitigation: Upsert idempotent theo `server_word_id`; không gây duplicate, chỉ tốn bandwidth thêm. Cải thiện sau bằng exclude list.
- **[Risk] Refresh worker chạy khi offline** → Mitigation: Wrap tất cả network calls trong try-catch; lỗi network log warning, retry lần sau; không crash app.
- **[Risk] Counter `words_studied_since_last_refresh` tăng nhanh khi test** → Mitigation: Threshold configurable qua `dart-define`, default 100.

## Migration Plan

1. Thêm cột/keys mới vào `app_settings` table (không cần DB migration, dùng upsert key-value store hiện có).
2. Ship `VocabularyRefreshWorker` cùng logic prefetch.
3. Khi app khởi động lần đầu sau update: `is_prefetch_done = false` → trigger prefetch tự động.
4. Rollback: Nếu worker crash, `WordRepository` vẫn hoạt động bình thường (on-demand fetch từ backend làm fallback). Không có breaking changes.

## Open Questions

- Resolved: do not use `/v1/words/next` or long `exclude_ids`; use
  `/v1/learning/cards` and cache inventory.
- `VocabularyRefreshWorker` có cần chạy khi app ở background (dùng `workmanager` package) hay chỉ chạy khi app foreground?
