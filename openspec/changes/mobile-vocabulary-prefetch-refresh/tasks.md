## 1. App Settings Keys & LocalDatabase

> Current-state note (2026-05-06): these tasks are historical. Do not implement
> the `/v1/words/recent`/exclude-list pieces as written. Current implementation
> uses ObjectBox, `LocalDatabase.addBatch()` for capped writes,
> `POST /v1/learning/cards` for refill/top-up, and `PUT /v1/user-word-cache`
> for duplicate-avoidance inventory.

- [ ] 1.1 Thêm key constants `is_prefetch_done`, `last_daily_refresh_date`, `words_studied_since_last_refresh` vào `LocalDatabase` (hoặc constants file riêng)
- [ ] 1.2 Thêm method `getSetting(String key)` và `setSetting(String key, String value)` vào `LocalDatabase` nếu chưa có generic key-value API
- [ ] 1.3 Thêm method `countUnstudiedNewWords()` vào `LocalDatabase` trả về số từ chưa học trong local store
- [ ] 1.4 Viết unit tests cho các methods mới trong `LocalDatabase`

## 2. VocabularyRefreshWorker

- [ ] 2.1 Tạo file `mobile/lib/src/data/vocabulary_refresh_worker.dart` với class `VocabularyRefreshWorker`
- [ ] 2.2 Implement method `runPrefetch()`: gọi backend `/v1/words/recent?limit=1000`, upsert vào local DB, set `is_prefetch_done=true`
- [ ] 2.3 Implement method `runDailyRefresh()`: fetch 150 từ mới (exclude existing `server_word_id`), upsert, prune to 1000, update `last_daily_refresh_date`
- [ ] 2.4 Implement method `runProactiveRefresh(int needed)`: fetch `needed` từ mới từ backend và upsert vào local DB
- [ ] 2.5 Xử lý network errors trong tất cả methods: catch exception, log warning, không update state khi lỗi
- [ ] 2.6 Viết unit tests cho `VocabularyRefreshWorker` (mock `BackendApiClient` và `LocalDatabase`)

## 3. BackendApiClient — fetchRecentWords

- [ ] 3.1 Thêm method `fetchRecentWords({required String deviceId, int limit = 1000, List<String>? excludeIds})` vào `BackendApiClient`
- [ ] 3.2 Build query string với `exclude_ids` nếu list không rỗng (hoặc bỏ qua nếu backend không hỗ trợ, dùng client-side dedup)
- [ ] 3.3 Parse response JSON thành `List<VocabularyWord>`
- [ ] 3.4 Viết unit tests cho `fetchRecentWords` với mock HTTP responses

## 4. WordRepository — Prefetch & Refresh Integration

- [ ] 4.1 Thêm field `VocabularyRefreshWorker _refreshWorker` vào `WordRepository` constructor
- [ ] 4.2 Thêm method `checkAndRunFirstInstallPrefetch()` vào `WordRepository`: đọc `is_prefetch_done`, nếu false thì gọi `_refreshWorker.runPrefetch()` async
- [ ] 4.3 Thêm method `checkAndRunDailyRefresh()` vào `WordRepository`: so sánh `last_daily_refresh_date` với ngày hôm nay, trigger nếu cần
- [ ] 4.4 Thêm method `recordWordStudied()` vào `WordRepository`: tăng `words_studied_since_last_refresh`, check milestone (% 100 == 0), nếu đủ điều kiện thì check số từ mới < 15 và trigger proactive refresh
- [ ] 4.5 Gọi `recordWordStudied()` bên trong `rateWord()` / `rateCurrent()` flow sau khi rating được lưu
- [ ] 4.6 Viết unit tests cho các methods mới trong `WordRepository`

## 5. App Startup Integration

- [ ] 5.1 Trong `main.dart`, sau khi khởi tạo `WordRepository`, gọi `repository.checkAndRunFirstInstallPrefetch()` async (không await, không block startup)
- [ ] 5.2 Gọi `repository.checkAndRunDailyRefresh()` async trong startup flow
- [ ] 5.3 Đảm bảo startup không crash nếu prefetch/refresh throw exception (wrap trong try-catch, log error)

## 6. Config

- [ ] 6.1 Thêm `prefetchLimit` (default 1000), `dailyRefreshCount` (default 150), `proactiveRefreshThreshold` (default 100), `proactiveRefreshMinNew` (default 15) vào `AppConfig`
- [ ] 6.2 Map các config values vào `--dart-define` constants: `VOCAB_PREFETCH_LIMIT`, `VOCAB_DAILY_REFRESH_COUNT`, `VOCAB_PROACTIVE_THRESHOLD`, `VOCAB_PROACTIVE_MIN_NEW`

## 7. Integration & End-to-End Tests

- [ ] 7.1 Thêm integration test: first launch → prefetch triggered → local word count tăng lên
- [ ] 7.2 Thêm test: daily refresh trigger khi ngày thay đổi
- [ ] 7.3 Thêm test: proactive refresh trigger sau khi học đủ 100 từ và số từ mới < 15
- [ ] 7.4 Thêm test: offline khi refresh → log warning, không crash, state không thay đổi
- [ ] 7.5 Chạy toàn bộ test suite mobile, đảm bảo không có regression
