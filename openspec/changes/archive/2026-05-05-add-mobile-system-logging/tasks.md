## 1. Logging Foundation

- [x] 1.1 Tạo module `mobile/lib/src/logging/` gồm `LogEntry`, `LogLevel`, `LogCategory`, và `Logger` interface với schema thống nhất.
- [x] 1.2 Triển khai `LogSanitizer` để redact token/password/app-secret/các key nhạy cảm trước khi lưu và trước khi export.
- [x] 1.3 Bổ sung unit tests cho serialization, level filtering, trace correlation, và redaction edge cases.

## 2. Local Persistence and Retention

- [x] 2.1 Mở rộng `LocalDatabase` với bảng log (migration version mới) và API query theo level/category/time range.
- [x] 2.2 Triển khai retention policy theo số bản ghi tối đa và tuổi log, kèm cleanup định kỳ khi ghi mới.
- [x] 2.3 Bổ sung tests cho migration, retention, restart persistence, và hiệu năng truy vấn danh sách log.

## 3. Runtime Instrumentation

- [x] 3.1 Instrument `backend_api_client.dart` để log request/response/error với context đã sanitize và `traceId`.
- [x] 3.2 Instrument `word_repository.dart`, `sync_worker.dart`, `local_database.dart` để log fallback path, sync retry, DB failure/success.
- [x] 3.3 Instrument `learning_session_controller.dart` để log navigation action, rating action, và scheduling decision.
- [x] 3.4 Thêm test xác minh các luồng new-word fallback và sync queue tạo log đúng level/category.

## 4. In-App Viewer and Export

- [x] 4.1 Tạo màn hình xem log trong app (drawer/settings entry) với filter level/category/date và phân trang.
- [x] 4.2 Triển khai export log ra file shareable (ưu tiên JSONL) chỉ chứa nội dung đã sanitize.
- [x] 4.3 Bổ sung widget/integration tests cho log viewer, filter behavior, và export flow trên thiết bị.

## 5. Rollout and Validation

- [x] 5.1 Thêm cấu hình mức log theo môi trường (production mặc định info+, debug có thể bật debug level).
- [x] 5.2 Chạy regression test cho learning session, local cache sync, auth flow để đảm bảo logging không phá hành vi cũ.
- [x] 5.3 Viết tài liệu vận hành ngắn: cách mở log viewer, lọc log, export file, và checklist debug từ máy thật.
