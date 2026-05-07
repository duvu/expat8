## Why

> Current-state note (2026-05-06): this proposal has been superseded by the
> ObjectBox migration and backend-managed learning-card flow. Current mobile
> storage is ObjectBox, and learner-specific refill uses
> `POST /v1/learning/cards` plus `PUT /v1/user-word-cache`, not SQLite,
> `/v1/words/next`, or recent-word exclusion lists. Treat the original text
> below as historical context unless it agrees with that current architecture.

Hiện tại app mobile chỉ tải từng từ mới từ backend theo yêu cầu (on-demand), khiến người dùng phụ thuộc vào kết nối mạng ổn định khi học. Cần xây dựng cơ chế tải trước (prefetch) tối đa 1000 từ vào local database ngay khi cài đặt, và duy trì tập từ này luôn "tươi" bằng cách thay thế 15% số từ cũ mỗi ngày—đảm bảo người dùng luôn có đủ từ để học ngay cả khi offline.

## What Changes

- **Bulk prefetch on first install**: Sau khi cài đặt, app gọi endpoint bootstrap để tải tối đa 1000 từ vào local database trong một lần (hoặc nhiều batch).
- **Daily vocabulary refresh**: Mỗi ngày, background worker thay thế 15% số từ hiện có (~150 từ / ngày) bằng từ mới từ backend, giữ local store luôn ≤ 1000 từ.
- **Proportional refresh trigger**: Sau mỗi 100 từ người dùng học, app tính toán để đảm bảo có khoảng 15 từ mới sẵn sàng trong local database (tỷ lệ 15:100). Worker refresh chạy proactive nếu tỷ lệ từ mới chưa học < 15%.
- **New words always served from local**: Người dùng không bao giờ phải chờ backend khi học từ mới—mọi từ mới đều được phục vụ từ local database.
- **Local cap enforcement**: Local database luôn giữ ≤ 1000 từ; khi thêm từ mới vào, các từ cũ nhất (đã học hết) sẽ bị loại bỏ trước.

## Capabilities

### New Capabilities

- `mobile-vocabulary-prefetch`: Tải trước tối đa 1000 từ từ backend khi cài đặt lần đầu, bao gồm batch download và progress tracking.
- `mobile-vocabulary-refresh`: Background refresh tự động 15%/ngày và trigger refresh proactive theo tỷ lệ từ mới học (15 từ mới / 100 từ đã học).

### Modified Capabilities

- `mobile-local-cache-sync`: Thêm yêu cầu prefetch khi khởi động lần đầu và cơ chế refresh định kỳ thay thế cho on-demand fetch từng từ.

## Impact

- **Mobile**: `WordRepository`, `SyncWorker` hoặc new `VocabularyRefreshWorker`, `LocalDatabase` (thêm cột tracking trạng thái prefetch và refresh timestamp), `main.dart` (trigger prefetch on first run).
- **Backend**: Current refill/top-up behavior uses `POST /v1/learning/cards`
  and cache inventory. `/v1/words/recent` remains read-only bootstrap support
  with only `limit` and `target_language`.
- **Config**: Thêm `VOCAB_PREFETCH_BATCH_SIZE`, `VOCAB_REFRESH_RATE_PERCENT`, `VOCAB_REFRESH_TRIGGER_INTERVAL`.
