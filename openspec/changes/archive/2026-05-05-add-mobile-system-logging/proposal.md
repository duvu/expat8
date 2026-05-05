## Why

Khi app mobile chạy trên máy thật hoặc môi trường production, team không thể dựa vào logcat/emulator để chẩn đoán lỗi mạng, lỗi đồng bộ, hay lỗi phiên đăng nhập. Cần có hệ thống log cục bộ có cấu trúc để truy vết nhanh sự cố mà không phụ thuộc kết nối debug trực tiếp.

## What Changes

- Thêm một logging subsystem trên mobile với event có cấu trúc (timestamp, level, category, message, context).
- Ghi log cho các luồng chính: khởi tạo app, API request/response, auth, sync queue, local DB, session actions.
- Lưu log cục bộ theo cơ chế xoay vòng (retention + max size) để tránh phình bộ nhớ.
- Thêm khả năng xem, lọc và xuất log (share file) ngay trong app để phục vụ debug từ thiết bị thật.
- Bổ sung cơ chế redaction để không ghi lộ token, secret, password, hoặc payload nhạy cảm.

## Capabilities

### New Capabilities
- `mobile-system-logging`: Hệ thống logging có cấu trúc, lưu cục bộ, cho phép lọc/xuất log và bảo vệ dữ liệu nhạy cảm để hỗ trợ debug/trace trên thiết bị thật.

### Modified Capabilities
- `mobile-local-cache-sync`: Bổ sung yêu cầu ghi log cho đồng bộ offline/online, queue retry, và lỗi DB/network liên quan đồng bộ.
- `mobile-learning-session`: Bổ sung yêu cầu ghi log cho vòng đời session học, load từ mới/review, và lỗi tương tác người dùng liên quan luồng học.

## Impact

- Mobile code: thêm module logger mới, hook vào `backend_api_client.dart`, `word_repository.dart`, `local_database.dart`, `sync_worker.dart`, `learning_session_controller.dart`.
- UI: thêm màn hình/entry để xem và chia sẻ log.
- Dữ liệu cục bộ: thêm bảng/log store hoặc file log cho persistence và retention.
- Test: thêm unit test cho redaction, retention, serialization; widget/integration test cho export/view log.
- Vận hành: tăng khả năng điều tra lỗi trên máy thật mà không cần emulator hoặc kết nối debugger trực tiếp.
